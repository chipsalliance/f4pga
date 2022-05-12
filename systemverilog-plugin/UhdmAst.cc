#include <algorithm>
#include <cstring>
#include <functional>
#include <regex>
#include <string>
#include <vector>

#include "UhdmAst.h"
#include "frontends/ast/ast.h"
#include "libs/sha1/sha1.h"

// UHDM
#include <uhdm/uhdm.h>
#include <uhdm/vpi_user.h>

YOSYS_NAMESPACE_BEGIN

/*static*/ const IdString &UhdmAst::partial()
{
    static const IdString id("\\partial");
    return id;
}
/*static*/ const IdString &UhdmAst::packed_ranges()
{
    static const IdString id("\\packed_ranges");
    return id;
}
/*static*/ const IdString &UhdmAst::unpacked_ranges()
{
    static const IdString id("\\unpacked_ranges");
    return id;
}
/*static*/ const IdString &UhdmAst::force_convert()
{
    static const IdString id("\\force_convert");
    return id;
}
/*static*/ const IdString &UhdmAst::is_imported()
{
    static const IdString id("\\is_imported");
    return id;
}

static void sanitize_symbol_name(std::string &name)
{
    if (!name.empty()) {
        auto pos = name.find_last_of('@');
        name = name.substr(pos + 1);
        // symbol names must begin with '\'
        name.insert(0, "\\");
    }
}

static std::string get_name(vpiHandle obj_h, bool prefer_full_name = false)
{
    auto first_check = prefer_full_name ? vpiFullName : vpiName;
    auto last_check = prefer_full_name ? vpiName : vpiFullName;
    std::string name;
    if (auto s = vpi_get_str(first_check, obj_h)) {
        name = s;
    } else if (auto s = vpi_get_str(vpiDefName, obj_h)) {
        name = s;
    } else if (auto s = vpi_get_str(last_check, obj_h)) {
        name = s;
    }
    if (name.rfind('.') != std::string::npos) {
        name = name.substr(name.rfind('.') + 1);
    }
    sanitize_symbol_name(name);
    return name;
}

static std::string strip_package_name(std::string name)
{
    auto sep_index = name.find("::");
    if (sep_index != string::npos) {
        name = name.substr(sep_index + 1);
        name[0] = '\\';
    }
    return name;
}

static std::string get_object_name(vpiHandle obj_h, const std::vector<int> &name_fields = {vpiName})
{
    std::string objectName;
    for (auto name : name_fields) {
        if (auto s = vpi_get_str(name, obj_h)) {
            objectName = s;
            sanitize_symbol_name(objectName);
            break;
        }
    }
    return objectName;
}

static AST::AstNode *make_range(int left, int right, bool is_signed = false)
{
    // generate a pre-validated range node for a fixed signal range.
    auto range = new AST::AstNode(AST::AST_RANGE);
    range->range_left = left;
    range->range_right = right;
    range->range_valid = true;
    range->children.push_back(AST::AstNode::mkconst_int(left, true));
    range->children.push_back(AST::AstNode::mkconst_int(right, true));
    range->is_signed = is_signed;
    return range;
}

static void copy_packed_unpacked_attribute(AST::AstNode *from, AST::AstNode *to)
{
    if (!to->attributes.count(UhdmAst::packed_ranges()))
        to->attributes[UhdmAst::packed_ranges()] = AST::AstNode::mkconst_int(1, false, 1);
    if (!to->attributes.count(UhdmAst::unpacked_ranges()))
        to->attributes[UhdmAst::unpacked_ranges()] = AST::AstNode::mkconst_int(1, false, 1);
    if (from->attributes.count(UhdmAst::packed_ranges())) {
        for (auto r : from->attributes[UhdmAst::packed_ranges()]->children) {
            to->attributes[UhdmAst::packed_ranges()]->children.push_back(r->clone());
        }
    }
    if (from->attributes.count(UhdmAst::unpacked_ranges())) {
        for (auto r : from->attributes[UhdmAst::unpacked_ranges()]->children) {
            to->attributes[UhdmAst::unpacked_ranges()]->children.push_back(r->clone());
        }
    }
}

#include "UhdmAstUpstream.cc"

static int get_max_offset_struct(AST::AstNode *node)
{
    // get the width from the MS member in the struct
    // as members are laid out from left to right in the packed wire
    log_assert(node->type == AST::AST_STRUCT || node->type == AST::AST_UNION);
    while (node->range_left < 0) {
        node = node->children[0];
    }
    return node->range_left;
}

static void visitEachDescendant(AST::AstNode *node, const std::function<void(AST::AstNode *)> &f)
{
    for (auto child : node->children) {
        f(child);
        visitEachDescendant(child, f);
    }
}

static void add_multirange_wire(AST::AstNode *node, std::vector<AST::AstNode *> packed_ranges, std::vector<AST::AstNode *> unpacked_ranges,
                                bool reverse = true)
{
    node->attributes[UhdmAst::packed_ranges()] = AST::AstNode::mkconst_int(1, false, 1);
    if (!packed_ranges.empty()) {
        if (reverse)
            std::reverse(packed_ranges.begin(), packed_ranges.end());
        node->attributes[UhdmAst::packed_ranges()]->children.insert(node->attributes[UhdmAst::packed_ranges()]->children.end(), packed_ranges.begin(),
                                                                    packed_ranges.end());
    }

    node->attributes[UhdmAst::unpacked_ranges()] = AST::AstNode::mkconst_int(1, false, 1);
    if (!unpacked_ranges.empty()) {
        if (reverse)
            std::reverse(unpacked_ranges.begin(), unpacked_ranges.end());
        node->attributes[UhdmAst::unpacked_ranges()]->children.insert(node->attributes[UhdmAst::unpacked_ranges()]->children.end(),
                                                                      unpacked_ranges.begin(), unpacked_ranges.end());
    }
}

static size_t add_multirange_attribute(AST::AstNode *wire_node, const std::vector<AST::AstNode *> ranges)
{
    size_t size = 1;
    for (size_t i = 0; i < ranges.size(); i++) {
        log_assert(AST_INTERNAL::current_ast_mod);
        if (ranges[i]->children.size() == 1) {
            ranges[i]->children.push_back(ranges[i]->children[0]->clone());
        }
        while (ranges[i]->simplify(true, false, false, 1, -1, false, false)) {
        }
        // this workaround case, where yosys doesn't follow id2ast and simplifies it to resolve constant
        if (ranges[i]->children[0]->id2ast) {
            while (ranges[i]->children[0]->id2ast->simplify(true, false, false, 1, -1, false, false)) {
            }
        }
        if (ranges[i]->children[1]->id2ast) {
            while (ranges[i]->children[1]->id2ast->simplify(true, false, false, 1, -1, false, false)) {
            }
        }
        while (ranges[i]->simplify(true, false, false, 1, -1, false, false)) {
        }
        log_assert(ranges[i]->children[0]->type == AST::AST_CONSTANT);
        log_assert(ranges[i]->children[1]->type == AST::AST_CONSTANT);
        if (wire_node->type != AST::AST_STRUCT_ITEM) {
            wire_node->multirange_dimensions.push_back(min(ranges[i]->children[0]->integer, ranges[i]->children[1]->integer));
            wire_node->multirange_swapped.push_back(ranges[i]->range_swapped);
        }
        auto elem_size = max(ranges[i]->children[0]->integer, ranges[i]->children[1]->integer) -
                         min(ranges[i]->children[0]->integer, ranges[i]->children[1]->integer) + 1;
        if (wire_node->type != AST::AST_STRUCT_ITEM || (wire_node->type == AST::AST_STRUCT_ITEM && i == 0)) {
            wire_node->multirange_dimensions.push_back(elem_size);
        }
        size *= elem_size;
    }
    return size;
}

static AST::AstNode *convert_range(AST::AstNode *id, const std::vector<AST::AstNode *> packed_ranges,
                                   const std::vector<AST::AstNode *> unpacked_ranges, int i)
{
    log_assert(AST_INTERNAL::current_ast_mod);
    log_assert(AST_INTERNAL::current_scope.count(id->str));
    AST::AstNode *wire_node = AST_INTERNAL::current_scope[id->str];
    log_assert(!wire_node->multirange_dimensions.empty());
    int elem_size = 1;
    std::vector<int> single_elem_size;
    single_elem_size.push_back(elem_size);
    for (size_t j = 0; (j + 1) < wire_node->multirange_dimensions.size(); j = j + 2) {
        elem_size *= wire_node->multirange_dimensions[j + 1] - wire_node->multirange_dimensions[j];
        single_elem_size.push_back(elem_size);
    }
    std::reverse(single_elem_size.begin(), single_elem_size.end());
    log_assert(i < static_cast<int>(unpacked_ranges.size() + packed_ranges.size()));
    log_assert(!id->children.empty());
    AST::AstNode *result = nullptr;
    // we want to start converting from the end
    if (i < static_cast<int>(id->children.size()) - 1) {
        result = convert_range(id, packed_ranges, unpacked_ranges, i + 1);
    }
    // special case, we want to select whole wire
    if (id->children.size() == 0 && i == 0) {
        result = make_range(single_elem_size[i] - 1, 0);
    } else {
        AST::AstNode *range_left = nullptr;
        AST::AstNode *range_right = nullptr;
        if (id->children[i]->children.size() == 2) {
            range_left = id->children[i]->children[0]->clone();
            range_right = id->children[i]->children[1]->clone();
        } else {
            range_left = id->children[i]->children[0]->clone();
            range_right = id->children[i]->children[0]->clone();
        }
        if (!wire_node->multirange_swapped.empty()) {
            bool is_swapped = wire_node->multirange_swapped[wire_node->multirange_swapped.size() - i - 1];
            auto right_idx = wire_node->multirange_dimensions.size() - (i * 2) - 2;
            if (is_swapped) {
                auto left_idx = wire_node->multirange_dimensions.size() - (i * 2) - 1;
                auto elem_size = wire_node->multirange_dimensions[left_idx] - wire_node->multirange_dimensions[right_idx];
                range_left = new AST::AstNode(AST::AST_SUB, AST::AstNode::mkconst_int(elem_size - 1, false), range_left->clone());
                range_right = new AST::AstNode(AST::AST_SUB, AST::AstNode::mkconst_int(elem_size - 1, false), range_right->clone());
            } else if (wire_node->multirange_dimensions[right_idx] != 0) {
                range_left =
                  new AST::AstNode(AST::AST_SUB, range_left, AST::AstNode::mkconst_int(wire_node->multirange_dimensions[right_idx], false));
                range_right =
                  new AST::AstNode(AST::AST_SUB, range_right, AST::AstNode::mkconst_int(wire_node->multirange_dimensions[right_idx], false));
            }
        }
        range_left =
          new AST::AstNode(AST::AST_SUB,
                           new AST::AstNode(AST::AST_MUL, new AST::AstNode(AST::AST_ADD, range_left->clone(), AST::AstNode::mkconst_int(1, false)),
                                            AST::AstNode::mkconst_int(single_elem_size[i + 1], false)),
                           AST::AstNode::mkconst_int(1, false));
        range_right = new AST::AstNode(AST::AST_MUL, range_right->clone(), AST::AstNode::mkconst_int(single_elem_size[i + 1], false));
        if (result) {
            range_right = new AST::AstNode(AST::AST_ADD, range_right->clone(), result->children[1]->clone());
            range_left = new AST::AstNode(AST::AST_SUB, new AST::AstNode(AST::AST_ADD, range_right->clone(), result->children[0]->clone()),
                                          result->children[1]->clone());
        }
        result = new AST::AstNode(AST::AST_RANGE, range_left, range_right);
    }
    // return range from *current* selected range
    // in the end, it results in whole selected range
    id->basic_prep = true;
    return result;
}

static void resolve_wiretype(AST::AstNode *wire_node)
{
    AST::AstNode *wiretype_node = nullptr;
    if (!wire_node->children.empty()) {
        if (wire_node->children[0]->type == AST::AST_WIRETYPE) {
            wiretype_node = wire_node->children[0];
        }
    }
    if (wire_node->children.size() > 1) {
        if (wire_node->children[1]->type == AST::AST_WIRETYPE) {
            wiretype_node = wire_node->children[1];
        }
    }
    if (wiretype_node == nullptr)
        return;
    std::vector<AST::AstNode *> packed_ranges;
    std::vector<AST::AstNode *> unpacked_ranges;
    // First check if it has already defined ranges
    if (wire_node->attributes.count(UhdmAst::packed_ranges())) {
        for (auto r : wire_node->attributes[UhdmAst::packed_ranges()]->children) {
            packed_ranges.push_back(r->clone());
        }
    }
    if (wire_node->attributes.count(UhdmAst::unpacked_ranges())) {
        for (auto r : wire_node->attributes[UhdmAst::unpacked_ranges()]->children) {
            unpacked_ranges.push_back(r->clone());
        }
    }
    AST::AstNode *wiretype_ast = nullptr;
    log_assert(AST_INTERNAL::current_scope.count(wiretype_node->str));
    wiretype_ast = AST_INTERNAL::current_scope[wiretype_node->str];
    // we need to setup current top ast as this simplify
    // needs to have access to all already definied ids
    while (wire_node->simplify(true, false, false, 1, -1, false, false)) {
    }
    if (wiretype_ast->children[0]->type == AST::AST_STRUCT && wire_node->type == AST::AST_WIRE) {
        auto struct_width = get_max_offset_struct(wiretype_ast->children[0]);
        wire_node->range_left = struct_width;
        wire_node->children[0]->range_left = struct_width;
        wire_node->children[0]->children[0]->integer = struct_width;
    }
    if (wiretype_ast && wire_node->attributes.count(ID::wiretype)) {
        log_assert(wiretype_ast->type == AST::AST_TYPEDEF);
        wire_node->attributes[ID::wiretype]->id2ast = wiretype_ast->children[0];
    }
    if ((wire_node->children[0]->type == AST::AST_RANGE || (wire_node->children.size() > 1 && wire_node->children[1]->type == AST::AST_RANGE)) &&
        wire_node->multirange_dimensions.empty()) {
        if (wiretype_ast && !wiretype_ast->children.empty() && wiretype_ast->children[0]->attributes.count(UhdmAst::packed_ranges()) &&
            wiretype_ast->children[0]->attributes.count(UhdmAst::unpacked_ranges())) {
            for (auto r : wiretype_ast->children[0]->attributes[UhdmAst::packed_ranges()]->children) {
                packed_ranges.push_back(r->clone());
            }
            for (auto r : wiretype_ast->children[0]->attributes[UhdmAst::unpacked_ranges()]->children) {
                unpacked_ranges.push_back(r->clone());
            }
        } else {
            if (wire_node->children[0]->type == AST::AST_RANGE)
                packed_ranges.push_back(wire_node->children[0]);
            else if (wire_node->children[1]->type == AST::AST_RANGE)
                packed_ranges.push_back(wire_node->children[1]);
            else
                log_error("Unhandled case in resolve_wiretype!\n");
        }
        AST::AstNode *value = nullptr;
        if (wire_node->children[0]->type != AST::AST_RANGE) {
            value = wire_node->children[0]->clone();
        }
        wire_node->children.clear();
        if (value)
            wire_node->children.push_back(value);
        wire_node->attributes[UhdmAst::packed_ranges()] = AST::AstNode::mkconst_int(1, false, 1);
        if (!packed_ranges.empty()) {
            std::reverse(packed_ranges.begin(), packed_ranges.end());
            wire_node->attributes[UhdmAst::packed_ranges()]->children.insert(wire_node->attributes[UhdmAst::packed_ranges()]->children.end(),
                                                                             packed_ranges.begin(), packed_ranges.end());
        }

        wire_node->attributes[UhdmAst::unpacked_ranges()] = AST::AstNode::mkconst_int(1, false, 1);
        if (!unpacked_ranges.empty()) {
            wire_node->attributes[UhdmAst::unpacked_ranges()]->children.insert(wire_node->attributes[UhdmAst::unpacked_ranges()]->children.end(),
                                                                               unpacked_ranges.begin(), unpacked_ranges.end());
        }
    }
}

static void add_force_convert_attribute(AST::AstNode *wire_node, int val = 1)
{
    wire_node->attributes[UhdmAst::force_convert()] = AST::AstNode::mkconst_int(val, true);
}

static void check_memories(AST::AstNode *module_node)
{
    std::map<std::string, AST::AstNode *> memories;
    visitEachDescendant(module_node, [&](AST::AstNode *node) {
        if (node->str == "\\$readmemh") {
            if (node->children.size() != 2 || node->children[1]->str.empty() || node->children[1]->type != AST::AST_IDENTIFIER) {
                log_error("%s:%d: Wrong usage of '\\$readmemh'\n", node->filename.c_str(), node->location.first_line);
            }
            if (memories[node->children[1]->str])
                add_force_convert_attribute(memories[node->children[1]->str], 0);
        }
        if (node->type == AST::AST_WIRE) {
            const std::vector<AST::AstNode *> packed_ranges =
              node->attributes.count(UhdmAst::packed_ranges()) ? node->attributes[UhdmAst::packed_ranges()]->children : std::vector<AST::AstNode *>();
            const std::vector<AST::AstNode *> unpacked_ranges = node->attributes.count(UhdmAst::unpacked_ranges())
                                                                  ? node->attributes[UhdmAst::unpacked_ranges()]->children
                                                                  : std::vector<AST::AstNode *>();
            if (packed_ranges.size() == 1 && unpacked_ranges.size() == 1) {
                log_assert(!memories.count(node->str));
                memories[node->str] = node;
            }
        }
        if (node->type == AST::AST_IDENTIFIER && memories.count(node->str)) {
            if (!memories[node->str]->attributes.count(UhdmAst::force_convert()) && node->children.size() == 0) {
                add_force_convert_attribute(memories[node->str]);
            }
        }
    });
}

// This function is workaround missing support for multirange (with n-ranges) packed/unpacked nodes
// It converts multirange node to single-range node and translates access to this node
// to correct range
static void convert_packed_unpacked_range(AST::AstNode *wire_node)
{
    resolve_wiretype(wire_node);
    const std::vector<AST::AstNode *> packed_ranges = wire_node->attributes.count(UhdmAst::packed_ranges())
                                                        ? wire_node->attributes[UhdmAst::packed_ranges()]->children
                                                        : std::vector<AST::AstNode *>();
    const std::vector<AST::AstNode *> unpacked_ranges = wire_node->attributes.count(UhdmAst::unpacked_ranges())
                                                          ? wire_node->attributes[UhdmAst::unpacked_ranges()]->children
                                                          : std::vector<AST::AstNode *>();
    if (packed_ranges.empty() && unpacked_ranges.empty()) {
        wire_node->attributes.erase(UhdmAst::packed_ranges());
        wire_node->attributes.erase(UhdmAst::unpacked_ranges());
        wire_node->range_valid = true;
        return;
    }
    size_t size = 1;
    size_t packed_size = 1;
    size_t unpacked_size = 1;
    std::vector<AST::AstNode *> ranges;
    bool convert_node = packed_ranges.size() > 1 || unpacked_ranges.size() > 1 || wire_node->attributes.count(ID::wiretype) ||
                        wire_node->type == AST::AST_PARAMETER || wire_node->type == AST::AST_LOCALPARAM ||
                        ((wire_node->is_input || wire_node->is_output) && ((packed_ranges.size() > 0 || unpacked_ranges.size() > 0))) ||
                        (wire_node->attributes.count(UhdmAst::force_convert()) && wire_node->attributes[UhdmAst::force_convert()]->integer == 1);
    // Convert only when atleast 1 of the ranges has more then 1 range
    if (convert_node) {
        if (wire_node->multirange_dimensions.empty()) {
            packed_size = add_multirange_attribute(wire_node, packed_ranges);
            unpacked_size = add_multirange_attribute(wire_node, unpacked_ranges);
            size = packed_size * unpacked_size;
            ranges.push_back(make_range(size - 1, 0));
        }
    } else {
        for (auto r : packed_ranges) {
            ranges.push_back(r->clone());
        }
        for (auto r : unpacked_ranges) {
            ranges.push_back(r->clone());
        }
        // if there is only one packed and one unpacked range,
        // and wire is not port wire, change type to AST_MEMORY
        if (wire_node->type == AST::AST_WIRE && packed_ranges.size() == 1 && unpacked_ranges.size() == 1 && !wire_node->is_input &&
            !wire_node->is_output) {
            wire_node->type = AST::AST_MEMORY;
        }
    }

    if (wire_node->type == AST::AST_STRUCT_ITEM || wire_node->type == AST::AST_STRUCT) {
        wire_node->attributes.erase(UhdmAst::packed_ranges());
        wire_node->attributes.erase(UhdmAst::unpacked_ranges());
    }

    // Insert new range
    wire_node->children.insert(wire_node->children.end(), ranges.begin(), ranges.end());
}

static AST::AstNode *expand_dot(const AST::AstNode *current_struct, const AST::AstNode *search_node)
{
    AST::AstNode *current_struct_elem = nullptr;
    auto search_str = search_node->str.find("\\") == 0 ? search_node->str.substr(1) : search_node->str;
    auto struct_elem_it =
      std::find_if(current_struct->children.begin(), current_struct->children.end(), [&](AST::AstNode *node) { return node->str == search_str; });
    if (struct_elem_it == current_struct->children.end()) {
        current_struct->dumpAst(NULL, "struct >");
        log_error("Couldn't find search elem: %s in struct\n", search_str.c_str());
    }
    current_struct_elem = *struct_elem_it;

    AST::AstNode *left = nullptr, *right = nullptr;
    if (current_struct_elem->type == AST::AST_STRUCT_ITEM) {
        left = AST::AstNode::mkconst_int(current_struct_elem->range_left, true);
        right = AST::AstNode::mkconst_int(current_struct_elem->range_right, true);
    } else if (current_struct_elem->type == AST::AST_STRUCT) {
        // Struct can have multiple range, so to get size of 1 struct,
        // we get left range for first children, and right range for last children
        left = AST::AstNode::mkconst_int(current_struct_elem->children.front()->range_left, true);
        right = AST::AstNode::mkconst_int(current_struct_elem->children.back()->range_right, true);
    } else {
        // Structs currently can only have AST_STRUCT or AST_STRUCT_ITEM
        // so, it should never happen
        log_error("Found %s elem in struct that is currently unsupported!\n", type2str(current_struct_elem->type).c_str());
    }

    auto elem_size =
      new AST::AstNode(AST::AST_ADD, new AST::AstNode(AST::AST_SUB, left->clone(), right->clone()), AST::AstNode::mkconst_int(1, true));
    AST::AstNode *sub_dot = nullptr;
    AST::AstNode *struct_range = nullptr;

    for (auto c : search_node->children) {
        if (c->type == static_cast<int>(AST::AST_DOT)) {
            // There should be only 1 AST_DOT node children
            log_assert(!sub_dot);
            sub_dot = expand_dot(current_struct_elem, c);
        }
        if (c->type == AST::AST_RANGE) {
            // Currently supporting only 1 range
            log_assert(!struct_range);
            struct_range = c;
        }
    }
    if (sub_dot) {
        // First select correct element in first struct
        delete left;
        delete right;
        left = sub_dot->children[0];
        right = sub_dot->children[1];
    }
    if (struct_range) {
        // now we have correct element set,
        // but we still need to set correct struct
        log_assert(!struct_range->children.empty());
        if (current_struct_elem->type == AST::AST_STRUCT_ITEM) {
            // if we selecting range of struct item, just add this range
            // to our current select
            if (struct_range->children.size() == 2) {
                auto range_size = new AST::AstNode(
                  AST::AST_ADD, new AST::AstNode(AST::AST_SUB, struct_range->children[0]->clone(), struct_range->children[1]->clone()),
                  AST::AstNode::mkconst_int(1, true));
                right = new AST::AstNode(AST::AST_ADD, right->clone(), struct_range->children[1]->clone());
                left = new AST::AstNode(
                  AST::AST_ADD, left,
                  new AST::AstNode(AST::AST_ADD, struct_range->children[1]->clone(), new AST::AstNode(AST::AST_SUB, range_size, elem_size->clone())));
            } else if (struct_range->children.size() == 1) {
                if (!current_struct_elem->multirange_dimensions.empty()) {
                    right = new AST::AstNode(AST::AST_ADD, right,
                                             new AST::AstNode(AST::AST_MUL, struct_range->children[0]->clone(),
                                                              AST::AstNode::mkconst_int(current_struct_elem->multirange_dimensions.back(), true)));
                    delete left;
                    left = new AST::AstNode(AST::AST_ADD, right->clone(),
                                            AST::AstNode::mkconst_int(current_struct_elem->multirange_dimensions.back() - 1, true));
                } else {
                    right = new AST::AstNode(AST::AST_ADD, right, struct_range->children[0]->clone());
                    delete left;
                    left = right->clone();
                }
            } else {
                struct_range->dumpAst(NULL, "range >");
                log_error("Unhandled range select (AST_STRUCT_ITEM) in AST_DOT!\n");
            }
        } else if (current_struct_elem->type == AST::AST_STRUCT) {
            if (struct_range->children.size() == 2) {
                right = new AST::AstNode(AST::AST_ADD, right, struct_range->children[1]->clone());
                auto range_size = new AST::AstNode(
                  AST::AST_ADD, new AST::AstNode(AST::AST_SUB, struct_range->children[0]->clone(), struct_range->children[1]->clone()),
                  AST::AstNode::mkconst_int(1, true));
                left = new AST::AstNode(AST::AST_ADD, left, new AST::AstNode(AST::AST_SUB, range_size, elem_size->clone()));
            } else if (struct_range->children.size() == 1) {
                AST::AstNode *mul = new AST::AstNode(AST::AST_MUL, elem_size->clone(), struct_range->children[0]->clone());

                left = new AST::AstNode(AST::AST_ADD, left, mul);
                right = new AST::AstNode(AST::AST_ADD, right, mul->clone());
            } else {
                struct_range->dumpAst(NULL, "range >");
                log_error("Unhandled range select (AST_STRUCT) in AST_DOT!\n");
            }
        } else {
            log_error("Found %s elem in struct that is currently unsupported!\n", type2str(current_struct_elem->type).c_str());
        }
    }
    // Return range from the begining of *current* struct
    // When all AST_DOT are expanded it will return range
    // from original wire
    return new AST::AstNode(AST::AST_RANGE, left, right);
}

static AST::AstNode *convert_dot(AST::AstNode *wire_node, AST::AstNode *node, AST::AstNode *dot)
{
    AST::AstNode *struct_node = nullptr;
    if (wire_node->type == AST::AST_STRUCT) {
        struct_node = wire_node;
    } else if (wire_node->attributes.count(ID::wiretype)) {
        log_assert(wire_node->attributes[ID::wiretype]->id2ast);
        struct_node = wire_node->attributes[ID::wiretype]->id2ast;
    }
    log_assert(struct_node);
    auto expanded = expand_dot(struct_node, dot);
    if (node->children[0]->type == AST::AST_RANGE) {
        int struct_size_int = get_max_offset_struct(struct_node) + 1;
        log_assert(!wire_node->multirange_dimensions.empty());
        int range = wire_node->multirange_dimensions.back() - 1;
        if (!wire_node->attributes[UhdmAst::unpacked_ranges()]->children.empty() &&
            wire_node->attributes[UhdmAst::unpacked_ranges()]->children.back()->range_left == range) {
            expanded->children[1] = new AST::AstNode(
              AST::AST_ADD, expanded->children[1],
              new AST::AstNode(AST::AST_MUL, AST::AstNode::mkconst_int(struct_size_int, true, 32),
                               new AST::AstNode(AST::AST_SUB, AST::AstNode::mkconst_int(range, true, 32), node->children[0]->children[0]->clone())));
            expanded->children[0] = new AST::AstNode(
              AST::AST_ADD, expanded->children[0],
              new AST::AstNode(AST::AST_MUL, AST::AstNode::mkconst_int(struct_size_int, true, 32),
                               new AST::AstNode(AST::AST_SUB, AST::AstNode::mkconst_int(range, true, 32), node->children[0]->children[0]->clone())));
        } else {
            expanded->children[1] = new AST::AstNode(
              AST::AST_ADD, expanded->children[1],
              new AST::AstNode(AST::AST_MUL, AST::AstNode::mkconst_int(struct_size_int, true, 32), node->children[0]->children[0]->clone()));
            expanded->children[0] = new AST::AstNode(
              AST::AST_ADD, expanded->children[0],
              new AST::AstNode(AST::AST_MUL, AST::AstNode::mkconst_int(struct_size_int, true, 32), node->children[0]->children[0]->clone()));
        }
    }
    return expanded;
}

static void setup_current_scope(std::unordered_map<std::string, AST::AstNode *> top_nodes, AST::AstNode *current_top_node)
{
    for (auto it = top_nodes.begin(); it != top_nodes.end(); it++) {
        if (it->second->type == AST::AST_PACKAGE) {
            for (auto &o : it->second->children) {
                // import only parameters
                if (o->type == AST::AST_TYPEDEF || o->type == AST::AST_PARAMETER || o->type == AST::AST_LOCALPARAM) {
                    // add imported nodes to current scope
                    AST_INTERNAL::current_scope[it->second->str + std::string("::") + o->str.substr(1)] = o;
                    AST_INTERNAL::current_scope[o->str] = o;
                } else if (o->type == AST::AST_ENUM) {
                    AST_INTERNAL::current_scope[o->str] = o;
                    for (auto c : o->children) {
                        AST_INTERNAL::current_scope[c->str] = c;
                    }
                }
            }
        }
    }
    for (auto &o : current_top_node->children) {
        if (o->type == AST::AST_TYPEDEF || o->type == AST::AST_PARAMETER || o->type == AST::AST_LOCALPARAM) {
            AST_INTERNAL::current_scope[o->str] = o;
        } else if (o->type == AST::AST_ENUM) {
            AST_INTERNAL::current_scope[o->str] = o;
            for (auto c : o->children) {
                AST_INTERNAL::current_scope[c->str] = c;
            }
        }
    }
    // hackish way of setting current_ast_mod as it is required
    // for simplify to get references for already defined ids
    AST_INTERNAL::current_ast_mod = current_top_node;
    log_assert(AST_INTERNAL::current_ast_mod != nullptr);
}

static int range_width_local(AST::AstNode *node, AST::AstNode *rnode)
{
    log_assert(rnode->type == AST::AST_RANGE);
    if (!rnode->range_valid) {
        log_file_error(node->filename, node->location.first_line, "Size must be constant in packed struct/union member %s\n", node->str.c_str());
    }
    // note: range swapping has already been checked for
    return rnode->range_left - rnode->range_right + 1;
}

static void save_struct_array_width_local(AST::AstNode *node, int width)
{
    // stash the stride for the array
    node->multirange_dimensions.push_back(width);
}

static int simplify_struct(AST::AstNode *snode, int base_offset, AST::AstNode *parent_node)
{
    // Struct members will be laid out in the structure contiguously from left to right.
    // Union members all have zero offset from the start of the union.
    // Determine total packed size and assign offsets.  Store these in the member node.
    bool is_union = (snode->type == AST::AST_UNION);
    int offset = 0;
    int packed_width = -1;
    for (auto s : snode->children) {
        if (s->type == AST::AST_RANGE) {
            while (s->simplify(true, false, false, 1, -1, false, false)) {
            };
        }
    }
    // embeded struct or union with range?
    auto it = std::remove_if(snode->children.begin(), snode->children.end(), [](AST::AstNode *node) { return node->type == AST::AST_RANGE; });
    std::vector<AST::AstNode *> ranges(it, snode->children.end());
    snode->children.erase(it, snode->children.end());
    if (!ranges.empty()) {
        if (ranges.size() > 1) {
            log_file_error(ranges[1]->filename, ranges[1]->location.first_line,
                           "Currently support for custom-type with range is limited to single range\n");
        }
        for (auto range : ranges) {
            snode->multirange_dimensions.push_back(min(range->range_left, range->range_right));
            snode->multirange_dimensions.push_back(max(range->range_left, range->range_right) - min(range->range_left, range->range_right) + 1);
            snode->multirange_swapped.push_back(range->range_swapped);
        }
    }
    // examine members from last to first
    for (auto it = snode->children.rbegin(); it != snode->children.rend(); ++it) {
        auto node = *it;
        int width;
        if (node->type == AST::AST_STRUCT || node->type == AST::AST_UNION) {
            // embedded struct or union
            width = simplify_struct(node, base_offset + offset, parent_node);
            if (!node->multirange_dimensions.empty()) {
                int number_of_structs = 1;
                number_of_structs = node->multirange_dimensions.back();
                width *= number_of_structs;
            }
            // set range of struct
            node->range_right = base_offset + offset;
            node->range_left = base_offset + offset + width - 1;
            node->range_valid = true;
        } else {
            log_assert(node->type == AST::AST_STRUCT_ITEM);
            if (node->children.size() > 0 && node->children[0]->type == AST::AST_RANGE) {
                // member width e.g. bit [7:0] a
                width = range_width_local(node, node->children[0]);
                if (node->children.size() == 2) {
                    if (node->children[1]->type == AST::AST_RANGE) {
                        // unpacked array e.g. bit [63:0] a [0:3]
                        auto rnode = node->children[1];
                        int array_count = range_width_local(node, rnode);
                        if (array_count == 1) {
                            // C-type array size e.g. bit [63:0] a [4]
                            array_count = rnode->range_left;
                        }
                        save_struct_array_width_local(node, width);
                        width *= array_count;
                    } else {
                        // array element must be single bit for a packed array
                        log_file_error(node->filename, node->location.first_line, "Unpacked array in packed struct/union member %s\n",
                                       node->str.c_str());
                    }
                }
                // range nodes are now redundant
                for (AST::AstNode *child : node->children)
                    delete child;
                node->children.clear();
            } else if (node->children.size() == 1 && node->children[0]->type == AST::AST_MULTIRANGE) {
                // packed 2D array, e.g. bit [3:0][63:0] a
                auto rnode = node->children[0];
                if (rnode->children.size() != 2) {
                    // packed arrays can only be 2D
                    log_file_error(node->filename, node->location.first_line, "Unpacked array in packed struct/union member %s\n", node->str.c_str());
                }
                int array_count = range_width_local(node, rnode->children[0]);
                width = range_width_local(node, rnode->children[1]);
                save_struct_array_width_local(node, width);
                width *= array_count;
                // range nodes are now redundant
                for (AST::AstNode *child : node->children)
                    delete child;
                node->children.clear();
            } else if (node->range_left < 0) {
                // 1 bit signal: bit, logic or reg
                width = 1;
            } else {
                // already resolved and compacted
                width = node->range_left - node->range_right + 1;
            }
            if (is_union) {
                node->range_right = base_offset;
                node->range_left = base_offset + width - 1;
            } else {
                node->range_right = base_offset + offset;
                node->range_left = base_offset + offset + width - 1;
            }
            node->range_valid = true;
        }
        if (is_union) {
            // check that all members have the same size
            if (packed_width == -1) {
                // first member
                packed_width = width;
            } else {
                if (packed_width != width) {

                    log_file_error(node->filename, node->location.first_line, "member %s of a packed union has %d bits, expecting %d\n",
                                   node->str.c_str(), width, packed_width);
                }
            }
        } else {
            offset += width;
        }
    }
    if (!snode->str.empty() && parent_node && parent_node->type != AST::AST_TYPEDEF && parent_node->type != AST::AST_STRUCT &&
        AST_INTERNAL::current_scope.count(snode->str) != 0) {
        AST_INTERNAL::current_scope[snode->str]->attributes[ID::wiretype] = AST::AstNode::mkconst_str(snode->str);
        AST_INTERNAL::current_scope[snode->str]->attributes[ID::wiretype]->id2ast = snode;
    }
    return (is_union ? packed_width : offset);
}

static void add_members_to_scope_local(AST::AstNode *snode, std::string name)
{
    // add all the members in a struct or union to local scope
    // in case later referenced in assignments
    log_assert(snode->type == AST::AST_STRUCT || snode->type == AST::AST_UNION);
    for (auto *node : snode->children) {
        auto member_name = name + "." + node->str;
        AST_INTERNAL::current_scope[member_name] = node;
        if (node->type != AST::AST_STRUCT_ITEM) {
            // embedded struct or union
            add_members_to_scope_local(node, name + "." + node->str);
        }
    }
}

static AST::AstNode *make_packed_struct_local(AST::AstNode *template_node, std::string &name)
{
    // create a wire for the packed struct
    auto wnode = new AST::AstNode(AST::AST_WIRE);
    wnode->str = name;
    wnode->is_logic = true;
    wnode->range_valid = true;
    wnode->is_signed = template_node->is_signed;
    int offset = get_max_offset_struct(template_node);
    auto range = make_range(offset, 0);
    copy_packed_unpacked_attribute(template_node, wnode);
    wnode->attributes[UhdmAst::packed_ranges()]->children.insert(wnode->attributes[UhdmAst::packed_ranges()]->children.begin(), range);
    // make sure this node is the one in scope for this name
    AST_INTERNAL::current_scope[name] = wnode;
    // add all the struct members to scope under the wire's name
    add_members_to_scope_local(template_node, name);
    return wnode;
}

static void simplify_format_string(AST::AstNode *current_node)
{
    std::string sformat = current_node->children[0]->str;
    std::string preformatted_string = "";
    int next_arg = 1;
    for (size_t i = 0; i < sformat.length(); i++) {
        if (sformat[i] == '%') {
            AST::AstNode *node_arg = current_node->children[next_arg];
            char cformat = sformat[++i];
            if (cformat == 'b' or cformat == 'B') {
                node_arg->simplify(true, false, false, 1, -1, false, false);
                if (node_arg->type != AST::AST_CONSTANT)
                    log_file_error(current_node->filename, current_node->location.first_line,
                                   "Failed to evaluate system task `%s' with non-constant argument.\n", current_node->str.c_str());

                RTLIL::Const val = node_arg->bitsAsConst();
                for (int j = val.size() - 1; j >= 0; j--) {
                    // We add ACII value of 0 to convert number to character
                    preformatted_string += ('0' + val[j]);
                }
                delete current_node->children[next_arg];
                current_node->children.erase(current_node->children.begin() + next_arg);
            } else {
                next_arg++;
                preformatted_string += std::string("%") + cformat;
            }
        } else {
            preformatted_string += sformat[i];
        }
    }
    delete current_node->children[0];
    current_node->children[0] = AST::AstNode::mkconst_str(preformatted_string);
}

static void simplify(AST::AstNode *current_node, AST::AstNode *parent_node)
{
    auto dot_it =
      std::find_if(current_node->children.begin(), current_node->children.end(), [](auto c) { return c->type == static_cast<int>(AST::AST_DOT); });
    AST::AstNode *dot = (dot_it != current_node->children.end()) ? *dot_it : nullptr;

    AST::AstNode *expanded = nullptr;
    if (dot) {
        if (!AST_INTERNAL::current_scope.count(current_node->str)) {
            // for accessing elements currently unsupported with AST_DOT
            // fallback to "." notation
            AST::AstNode *prefix_node = nullptr;
            AST::AstNode *parent_node = current_node;
            while (dot && !dot->str.empty()) {
                // it is not possible for AST_RANGE to be after AST::DOT (see process_hier_path function)
                if (parent_node->children[0]->type == AST::AST_RANGE) {
                    if (parent_node->children[1]->type == AST::AST_RANGE)
                        log_error("Multirange in AST_DOT is currently unsupported\n");

                    dot->type = AST::AST_IDENTIFIER;
                    simplify(dot, nullptr);
                    AST::AstNode *range_const = parent_node->children[0]->children[0];
                    prefix_node = new AST::AstNode(AST::AST_PREFIX, range_const->clone(), dot->clone());
                    break;
                } else {
                    current_node->str += "." + dot->str.substr(1);
                    dot_it =
                      std::find_if(dot->children.begin(), dot->children.end(), [](auto c) { return c->type == static_cast<int>(AST::AST_DOT); });
                    parent_node = dot;
                    dot = (dot_it != dot->children.end()) ? *dot_it : nullptr;
                }
            }
            current_node->delete_children();
            if (prefix_node != nullptr) {
                current_node->type = AST::AST_PREFIX;
                current_node->children = prefix_node->children;
            }
        } else {
            auto wire_node = AST_INTERNAL::current_scope[current_node->str];
            // make sure wire_node is already simplified
            simplify(wire_node, nullptr);
            expanded = convert_dot(wire_node, current_node, dot);
        }
    }
    if (expanded) {
        for (size_t i = 0; i < current_node->children.size(); i++) {
            delete current_node->children[i];
        }
        current_node->children.clear();
        current_node->children.push_back(expanded->clone());
        current_node->basic_prep = true;
        expanded = nullptr;
    }
    // First simplify children
    for (size_t i = 0; i < current_node->children.size(); i++) {
        simplify(current_node->children[i], current_node);
    }
    switch (current_node->type) {
    case AST::AST_TYPEDEF:
    case AST::AST_ENUM:
    case AST::AST_FUNCTION:
        AST_INTERNAL::current_scope[current_node->str] = current_node;
        break;
    case AST::AST_WIRE:
    case AST::AST_PARAMETER:
    case AST::AST_LOCALPARAM:
        AST_INTERNAL::current_scope[current_node->str] = current_node;
        convert_packed_unpacked_range(current_node);
        break;
    case AST::AST_IDENTIFIER:
        if (!current_node->children.empty() && !current_node->basic_prep) {
            log_assert(AST_INTERNAL::current_ast_mod);
            if (!AST_INTERNAL::current_scope.count(current_node->str)) {
                break;
            }
            AST::AstNode *wire_node = AST_INTERNAL::current_scope[current_node->str];
            simplify(wire_node, nullptr);
            const std::vector<AST::AstNode *> packed_ranges = wire_node->attributes.count(UhdmAst::packed_ranges())
                                                                ? wire_node->attributes[UhdmAst::packed_ranges()]->children
                                                                : std::vector<AST::AstNode *>();
            const std::vector<AST::AstNode *> unpacked_ranges = wire_node->attributes.count(UhdmAst::unpacked_ranges())
                                                                  ? wire_node->attributes[UhdmAst::unpacked_ranges()]->children
                                                                  : std::vector<AST::AstNode *>();
            if ((wire_node->type == AST::AST_WIRE || wire_node->type == AST::AST_PARAMETER || wire_node->type == AST::AST_LOCALPARAM) &&
                !(packed_ranges.empty() && unpacked_ranges.empty()) && !(packed_ranges.size() + unpacked_ranges.size() == 1)) {
                auto result = convert_range(current_node, packed_ranges, unpacked_ranges, 0);
                for (size_t i = 0; i < current_node->children.size(); i++) {
                    delete current_node->children[i];
                }
                current_node->children.clear();
                current_node->children.push_back(result);
            }
        }
        break;
    case AST::AST_STRUCT:
        simplify_struct(current_node, 0, parent_node);
        // instance rather than just a type in a typedef or outer struct?
        if (!current_node->str.empty() && current_node->str[0] == '\\') {
            // instance so add a wire for the packed structure
            auto wnode = make_packed_struct_local(current_node, current_node->str);
            convert_packed_unpacked_range(wnode);
            log_assert(AST_INTERNAL::current_ast_mod);
            AST_INTERNAL::current_ast_mod->children.push_back(wnode);
            AST_INTERNAL::current_scope[wnode->str]->attributes[ID::wiretype] = AST::AstNode::mkconst_str(current_node->str);
            AST_INTERNAL::current_scope[wnode->str]->attributes[ID::wiretype]->id2ast = current_node;
        }

        current_node->basic_prep = true;
        break;
    case AST::AST_STRUCT_ITEM:
        AST_INTERNAL::current_scope[current_node->str] = current_node;
        convert_packed_unpacked_range(current_node);
        while (current_node->simplify(true, false, false, 1, -1, false, false)) {
        };
        break;
    case AST::AST_TCALL:
        if (current_node->str == "$display" || current_node->str == "$write")
            simplify_format_string(current_node);
        break;
    default:
        break;
    }
}

static void clear_current_scope()
{
    // Remove clear current_scope from package nodes
    AST_INTERNAL::current_scope.clear();
    // unset current_ast_mod
    AST_INTERNAL::current_ast_mod = nullptr;
}

static void mark_as_unsigned(AST::AstNode *node, const UHDM::BaseClass *object)
{
    if (node->children.empty() || node->children.size() == 1) {
        node->is_signed = false;
    } else if (node->children.size() == 2) {
        node->children[0]->is_signed = false;
        node->children[1]->is_signed = false;
    } else {
        log_error("%s:%d: Unsupported expression in mark_as_unsigned!\n", object->VpiFile().c_str(), object->VpiLineNo());
    }
}

void UhdmAst::visit_one_to_many(const std::vector<int> child_node_types, vpiHandle parent_handle, const std::function<void(AST::AstNode *)> &f)
{
    for (auto child : child_node_types) {
        vpiHandle itr = vpi_iterate(child, parent_handle);
        while (vpiHandle vpi_child_obj = vpi_scan(itr)) {
            UhdmAst uhdm_ast(this, shared, indent + "  ");
            auto *child_node = uhdm_ast.process_object(vpi_child_obj);
            f(child_node);
            vpi_release_handle(vpi_child_obj);
        }
        vpi_release_handle(itr);
    }
}

void UhdmAst::visit_one_to_one(const std::vector<int> child_node_types, vpiHandle parent_handle, const std::function<void(AST::AstNode *)> &f)
{
    for (auto child : child_node_types) {
        vpiHandle itr = vpi_handle(child, parent_handle);
        if (itr) {
            UhdmAst uhdm_ast(this, shared, indent + "  ");
            auto *child_node = uhdm_ast.process_object(itr);
            f(child_node);
        }
        vpi_release_handle(itr);
    }
}

void UhdmAst::visit_range(vpiHandle obj_h, const std::function<void(AST::AstNode *)> &f)
{
    std::vector<AST::AstNode *> range_nodes;
    visit_one_to_many({vpiRange}, obj_h, [&](AST::AstNode *node) { range_nodes.push_back(node); });
    if (range_nodes.size() > 1) {
        auto multirange_node = new AST::AstNode(AST::AST_MULTIRANGE);
        multirange_node->children = range_nodes;
        f(multirange_node);
    } else if (!range_nodes.empty()) {
        f(range_nodes[0]);
    }
}

void UhdmAst::visit_default_expr(vpiHandle obj_h)
{
    UhdmAst initial_ast(parent, shared, indent);
    UhdmAst block_ast(&initial_ast, shared, indent);
    block_ast.visit_one_to_one({vpiExpr}, obj_h, [&](AST::AstNode *expr_node) {
        auto mod = find_ancestor({AST::AST_MODULE});
        AST::AstNode *initial_node = nullptr;
        AST::AstNode *block_node = nullptr;
        auto assign_node = new AST::AstNode(AST::AST_ASSIGN_EQ);
        auto id_node = new AST::AstNode(AST::AST_IDENTIFIER);
        id_node->str = current_node->str;

        for (auto child : mod->children) {
            if (child->type == AST::AST_INITIAL) {
                initial_node = child;
                break;
            }
        }
        // Ensure single AST_INITIAL node is located in AST_MODULE
        // before any AST_ALWAYS
        if (initial_node == nullptr) {
            initial_node = new AST::AstNode(AST::AST_INITIAL);
            auto insert_it = find_if(mod->children.begin(), mod->children.end(), [](AST::AstNode *node) { return (node->type == AST::AST_ALWAYS); });
            mod->children.insert(insert_it, initial_node);
        }
        // Ensure single AST_BLOCK node in AST_INITIAL
        if (!initial_node->children.empty() && initial_node->children[0]) {
            block_node = initial_node->children[0];
        } else {
            block_node = new AST::AstNode(AST::AST_BLOCK);
            initial_node->children.push_back(block_node);
        }
        auto block_child =
          find_if(block_node->children.begin(), block_node->children.end(), [](AST::AstNode *node) { return (node->type == AST::AST_ASSIGN_EQ); });
        // Insert AST_ASSIGN_EQ nodes that came from
        // custom_var or int_var before any other AST_ASSIGN_EQ
        // Especially before ones explicitly placed in initial block in source code
        block_node->children.insert(block_child, assign_node);
        assign_node->children.push_back(id_node);
        initial_ast.current_node = initial_node;
        block_ast.current_node = block_node;
        assign_node->children.push_back(expr_node);
    });
}

AST::AstNode *UhdmAst::process_value(vpiHandle obj_h)
{
    s_vpi_value val;
    vpi_get_value(obj_h, &val);
    std::string strValType;
    if (val.format) { // Needed to handle parameter nodes without typespecs and constants
        switch (val.format) {
        case vpiScalarVal:
            return AST::AstNode::mkconst_int(val.value.scalar, false, 1);
        case vpiBinStrVal: {
            strValType = "'b";
            break;
        }
        case vpiDecStrVal: {
            strValType = "'d";
            break;
        }
        case vpiHexStrVal: {
            strValType = "'h";
            break;
        }
        case vpiOctStrVal: {
            strValType = "'o";
            break;
        }
        // Surelog reports constant integers as a unsigned, but by default int is signed
        // so we are treating here UInt in the same way as if they would be Int
        case vpiUIntVal:
        case vpiIntVal: {
            int size = -1;
            bool is_signed = false;
            // Surelog sometimes report size as part of vpiTypespec (e.g. int_typespec)
            // if it is the case, we need to set size to the left_range of first packed range
            visit_one_to_one({vpiTypespec}, obj_h, [&](AST::AstNode *node) {
                if (node && node->attributes.count(UhdmAst::packed_ranges()) && node->attributes[UhdmAst::packed_ranges()]->children.size() &&
                    node->attributes[UhdmAst::packed_ranges()]->children[0]->children.size()) {
                    size = node->attributes[UhdmAst::packed_ranges()]->children[0]->children[0]->integer + 1;
                }
            });
            if (size == -1) {
                size = vpi_get(vpiSize, obj_h);
            }
            // Surelog by default returns 64 bit numbers and stardard says that they shall be at least 32bits
            // yosys is assuming that int/uint is 32 bit, so we are setting here correct size
            // NOTE: it *shouldn't* break on explicite 64 bit const values, as they *should* be handled
            // above by vpi*StrVal
            // FIXME: Minimal int size should be resolved in UHDM, here we make sure it is at least 32
            if (size == 64 || size < 32) {
                size = 32;
                is_signed = true;
            }
            auto c = AST::AstNode::mkconst_int(val.value.integer, is_signed, size > 0 ? size : 32);
            if (size == 0 || size == -1)
                c->is_unsized = true;
            return c;
        }
        case vpiRealVal:
            return mkconst_real(val.value.real);
        case vpiStringVal:
            return AST::AstNode::mkconst_str(val.value.str);
        default: {
            const uhdm_handle *const handle = (const uhdm_handle *)obj_h;
            const UHDM::BaseClass *const object = (const UHDM::BaseClass *)handle->object;
            report_error("%s:%d: Encountered unhandled constant format %d\n", object->VpiFile().c_str(), object->VpiLineNo(), val.format);
        }
        }
        // handle vpiBinStrVal, vpiDecStrVal and vpiHexStrVal
        if (std::strchr(val.value.str, '\'')) {
            return VERILOG_FRONTEND::const2ast(val.value.str, 0, false);
        } else {
            auto size = vpi_get(vpiSize, obj_h);
            if (size == 0) {
                auto c = AST::AstNode::mkconst_int(atoi(val.value.str), true, 32);
                c->is_unsized = true;
                return c;
            } else {
                return VERILOG_FRONTEND::const2ast(std::to_string(size) + strValType + val.value.str, 0, false);
            }
        }
    }
    return nullptr;
}

AST::AstNode *UhdmAst::make_ast_node(AST::AstNodeType type, std::vector<AST::AstNode *> children, bool prefer_full_name)
{
    auto node = new AST::AstNode(type);
    node->str = get_name(obj_h, prefer_full_name);
    auto it = node_renames.find(node->str);
    if (it != node_renames.end())
        node->str = it->second;
    if (auto filename = vpi_get_str(vpiFile, obj_h)) {
        node->filename = filename;
    }
    if (unsigned int line = vpi_get(vpiLineNo, obj_h)) {
        node->location.first_line = node->location.last_line = line;
    }
    node->children = children;
    return node;
}

void UhdmAst::process_packed_array_typespec()
{
    std::vector<AST::AstNode *> packed_ranges;
    std::vector<AST::AstNode *> unpacked_ranges;
    current_node = make_ast_node(AST::AST_WIRE);
    visit_one_to_many({vpiRange}, obj_h, [&](AST::AstNode *node) { packed_ranges.push_back(node); });
    visit_one_to_one({vpiElemTypespec}, obj_h, [&](AST::AstNode *node) {
        if (node && node->type == AST::AST_STRUCT) {
            auto str = current_node->str;
            node->cloneInto(current_node);
            current_node->str = str;
            delete node;
        } else if (node) {
            current_node->str = node->str;
            if (node->type == AST::AST_ENUM && !node->children.empty()) {
                for (auto c : node->children[0]->children) {
                    if (c->type == AST::AST_RANGE && c->str.empty())
                        packed_ranges.push_back(c->clone());
                }
            }
            delete node;
        }
    });
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges);
}

static void add_or_replace_child(AST::AstNode *parent, AST::AstNode *child)
{
    if (!child->str.empty()) {
        auto it = std::find_if(parent->children.begin(), parent->children.end(),
                               [child](AST::AstNode *existing_child) { return existing_child->str == child->str; });
        if (it != parent->children.end()) {
            // If port direction is already set, copy it to replaced child node
            if ((*it)->is_input || (*it)->is_output) {
                child->is_input = (*it)->is_input;
                child->is_output = (*it)->is_output;
                child->port_id = (*it)->port_id;
                if (child->type == AST::AST_MEMORY)
                    child->type = AST::AST_WIRE;
            }
            if (!(*it)->children.empty() && child->children.empty()) {
                // This is a bit ugly, but if the child we're replacing has children and
                // our node doesn't, we copy its children to not lose any information
                for (auto grandchild : (*it)->children) {
                    child->children.push_back(grandchild->clone());
                    if (child->type == AST::AST_WIRE && grandchild->type == AST::AST_WIRETYPE)
                        child->is_custom_type = true;
                }
            }
            if ((*it)->attributes.count(UhdmAst::packed_ranges()) && child->attributes.count(UhdmAst::packed_ranges())) {
                if ((!(*it)->attributes[UhdmAst::packed_ranges()]->children.empty() &&
                     child->attributes[UhdmAst::packed_ranges()]->children.empty())) {
                    child->attributes[UhdmAst::packed_ranges()] = (*it)->attributes[UhdmAst::packed_ranges()]->clone();
                }
            }
            if ((*it)->attributes.count(UhdmAst::unpacked_ranges()) && child->attributes.count(UhdmAst::unpacked_ranges())) {
                if ((!(*it)->attributes[UhdmAst::unpacked_ranges()]->children.empty() &&
                     child->attributes[UhdmAst::unpacked_ranges()]->children.empty())) {
                    child->attributes[UhdmAst::unpacked_ranges()] = (*it)->attributes[UhdmAst::unpacked_ranges()]->clone();
                }
            }
            // Surelog doesn't report correct sign value for param_assign nodes
            // and only default vpiParameter node have correct sign value, so
            // if we are overriding parameter, copy sign value from current node to the new node
            if (((*it)->type == AST::AST_PARAMETER || (*it)->type == AST::AST_LOCALPARAM) && child->children.size() && (*it)->children.size()) {
                child->children[0]->is_signed = (*it)->children[0]->is_signed;
            }
            delete *it;
            *it = child;
            return;
        }
        parent->children.push_back(child);
    } else if (child->type == AST::AST_INITIAL) {
        // Special case for initials
        // Ensure that there is only one AST_INITIAL in the design
        // And there is only one AST_BLOCK inside that initial
        // Copy nodes from child initial to parent initial
        auto initial_node_it =
          find_if(parent->children.begin(), parent->children.end(), [](AST::AstNode *node) { return (node->type == AST::AST_INITIAL); });
        if (initial_node_it != parent->children.end()) {
            AST::AstNode *initial_node = *initial_node_it;

            log_assert(!(initial_node->children.empty()));
            log_assert(initial_node->children[0]->type == AST::AST_BLOCK);
            log_assert(!(child->children.empty()));
            log_assert(child->children[0]->type == AST::AST_BLOCK);

            AST::AstNode *block_node = initial_node->children[0];
            AST::AstNode *child_block_node = child->children[0];

            // Place the contents of child block node inside parent block
            for (auto child_block_child : child_block_node->children)
                block_node->children.push_back(child_block_child->clone());
            // Place the remaining contents of child initial node inside the parent initial
            for (auto initial_child = child->children.begin() + 1; initial_child != child->children.end(); ++initial_child) {
                initial_node->children.push_back((*initial_child)->clone());
            }
        } else {
            // Parent AST_INITIAL does not exist
            // Place child AST_INITIAL before AST_ALWAYS if found
            auto insert_it =
              find_if(parent->children.begin(), parent->children.end(), [](AST::AstNode *node) { return (node->type == AST::AST_ALWAYS); });
            parent->children.insert(insert_it, 1, child);
        }
    } else {
        parent->children.push_back(child);
    }
}

void UhdmAst::make_cell(vpiHandle obj_h, AST::AstNode *cell_node, AST::AstNode *type_node)
{
    if (cell_node->children.empty() || (!cell_node->children.empty() && cell_node->children[0]->type != AST::AST_CELLTYPE)) {
        auto typeNode = new AST::AstNode(AST::AST_CELLTYPE);
        typeNode->str = type_node->str;
        cell_node->children.insert(cell_node->children.begin(), typeNode);
    }
    // Add port connections as arguments
    vpiHandle port_itr = vpi_iterate(vpiPort, obj_h);
    while (vpiHandle port_h = vpi_scan(port_itr)) {
        std::string arg_name;
        if (auto s = vpi_get_str(vpiName, port_h)) {
            arg_name = s;
            sanitize_symbol_name(arg_name);
        }
        auto arg_node = new AST::AstNode(AST::AST_ARGUMENT);
        arg_node->str = arg_name;
        arg_node->filename = cell_node->filename;
        arg_node->location = cell_node->location;
        visit_one_to_one({vpiHighConn}, port_h, [&](AST::AstNode *node) {
            if (node) {
                if (node->type == AST::AST_PARAMETER || node->type == AST::AST_LOCALPARAM) {
                    node->type = AST::AST_IDENTIFIER;
                }
                arg_node->children.push_back(node);
            }
        });
        cell_node->children.push_back(arg_node);
        shared.report.mark_handled(port_h);
        vpi_release_handle(port_h);
    }
    vpi_release_handle(port_itr);
}

void UhdmAst::move_type_to_new_typedef(AST::AstNode *current_node, AST::AstNode *type_node)
{
    auto typedef_node = new AST::AstNode(AST::AST_TYPEDEF);
    typedef_node->location = type_node->location;
    typedef_node->filename = type_node->filename;
    typedef_node->str = strip_package_name(type_node->str);
    for (auto c : current_node->children) {
        if (c->str == typedef_node->str) {
            return;
        }
    }
    if (type_node->type == AST::AST_STRUCT) {
        type_node->str.clear();
        typedef_node->children.push_back(type_node);
        current_node->children.push_back(typedef_node);
    } else if (type_node->type == AST::AST_ENUM) {
        if (type_node->attributes.count("\\enum_base_type")) {
            auto base_type = type_node->attributes["\\enum_base_type"];
            auto wire_node = new AST::AstNode(AST::AST_WIRE);
            wire_node->is_reg = true;
            for (auto c : base_type->children) {
                std::string enum_item_str = "\\enum_value_";
                log_assert(!c->children.empty());
                log_assert(c->children[0]->type == AST::AST_CONSTANT);
                int width = 1;
                bool is_signed = c->children[0]->is_signed;
                if (c->children.size() == 2) {
                    width = c->children[1]->children[0]->integer + 1;
                }
                RTLIL::Const val = c->children[0]->bitsAsConst(width, is_signed);
                enum_item_str.append(val.as_string());
                wire_node->attributes[enum_item_str.c_str()] = AST::AstNode::mkconst_str(c->str);
            }
            typedef_node->children.push_back(wire_node);
            current_node->children.push_back(typedef_node);
            delete type_node;
        } else {
            type_node->str = "$enum" + std::to_string(shared.next_enum_id());
            for (auto *enum_item : type_node->children) {
                enum_item->attributes["\\enum_base_type"] = AST::AstNode::mkconst_str(type_node->str);
            }
            auto wire_node = new AST::AstNode(AST::AST_WIRE);
            wire_node->is_reg = true;
            wire_node->attributes["\\enum_type"] = AST::AstNode::mkconst_str(type_node->str);
            if (!type_node->children.empty() && type_node->children[0]->children.size() > 1) {
                wire_node->children.push_back(type_node->children[0]->children[1]->clone());
            }
            typedef_node->children.push_back(wire_node);
            current_node->children.push_back(type_node);
            current_node->children.push_back(typedef_node);
        }
    } else {
        type_node->str.clear();
        typedef_node->children.push_back(type_node);
        current_node->children.push_back(typedef_node);
    }
}

AST::AstNode *UhdmAst::find_ancestor(const std::unordered_set<AST::AstNodeType> &types)
{
    auto searched_node = this;
    while (searched_node) {
        if (searched_node->current_node) {
            if (types.find(searched_node->current_node->type) != types.end()) {
                return searched_node->current_node;
            }
        }
        searched_node = searched_node->parent;
    }
    return nullptr;
}

void UhdmAst::process_design()
{
    current_node = make_ast_node(AST::AST_DESIGN);
    visit_one_to_many({UHDM::uhdmallInterfaces, UHDM::uhdmallPackages, UHDM::uhdmtopPackages, UHDM::uhdmallModules, UHDM::uhdmtopModules}, obj_h,
                      [&](AST::AstNode *node) {
                          if (node) {
                              shared.top_nodes[node->str] = node;
                          }
                      });
    visit_one_to_many({vpiParameter, vpiParamAssign}, obj_h, [&](AST::AstNode *node) {});
    visit_one_to_many({vpiTypedef}, obj_h, [&](AST::AstNode *node) {
        if (node)
            move_type_to_new_typedef(current_node, node);
    });
    for (auto pair : shared.top_nodes) {
        if (!pair.second)
            continue;
        if (pair.second->type == AST::AST_PACKAGE) {
            check_memories(pair.second);
            setup_current_scope(shared.top_nodes, pair.second);
            simplify(pair.second, nullptr);
            clear_current_scope();
        }
    }
    // Once we walked everything, unroll that as children of this node
    for (auto pair : shared.top_nodes) {
        if (!pair.second)
            continue;
        if (!pair.second->get_bool_attribute(UhdmAst::partial())) {
            if (pair.second->type == AST::AST_PACKAGE)
                current_node->children.insert(current_node->children.begin(), pair.second);
            else {
                check_memories(pair.second);
                setup_current_scope(shared.top_nodes, pair.second);
                simplify(pair.second, nullptr);
                clear_current_scope();
                current_node->children.push_back(pair.second);
            }
        } else {
            log_warning("Removing unused module: %s from the design.\n", pair.second->str.c_str());
            delete pair.second;
        }
    }
}

void UhdmAst::simplify_parameter(AST::AstNode *parameter, AST::AstNode *module_node)
{
    setup_current_scope(shared.top_nodes, shared.current_top_node);
    visitEachDescendant(shared.current_top_node, [&](AST::AstNode *current_scope_node) {
        if (current_scope_node->type == AST::AST_TYPEDEF || current_scope_node->type == AST::AST_PARAMETER ||
            current_scope_node->type == AST::AST_LOCALPARAM) {
            if (current_scope_node->type == AST::AST_TYPEDEF)
                simplify(current_scope_node, nullptr);
            AST_INTERNAL::current_scope[current_scope_node->str] = current_scope_node;
        }
    });
    if (module_node) {
        visitEachDescendant(module_node, [&](AST::AstNode *current_scope_node) {
            if (current_scope_node->type == AST::AST_TYPEDEF || current_scope_node->type == AST::AST_PARAMETER ||
                current_scope_node->type == AST::AST_LOCALPARAM) {
                AST_INTERNAL::current_scope[current_scope_node->str] = current_scope_node;
            }
        });
    }
    // first apply custom simplification step if needed
    simplify(parameter, nullptr);
    // then simplify parameter to AST_CONSTANT or AST_REALVALUE
    while (parameter->simplify(true, false, false, 1, -1, false, false)) {
    }
    clear_current_scope();
}

void UhdmAst::process_module()
{
    std::string type = vpi_get_str(vpiDefName, obj_h);
    std::string name = vpi_get_str(vpiName, obj_h) ? vpi_get_str(vpiName, obj_h) : type;
    bool is_module_instance = type != name;
    sanitize_symbol_name(type);
    sanitize_symbol_name(name);
    type = strip_package_name(type);
    name = strip_package_name(name);
    if (!is_module_instance) {
        if (shared.top_nodes.find(type) != shared.top_nodes.end()) {
            current_node = shared.top_nodes[type];
            shared.current_top_node = current_node;
            auto process_it = std::find_if(current_node->children.begin(), current_node->children.end(),
                                           [](auto node) { return node->type == AST::AST_INITIAL || node->type == AST::AST_ALWAYS; });
            auto children_after_process = std::vector<AST::AstNode *>(process_it, current_node->children.end());
            current_node->children.erase(process_it, current_node->children.end());
            visit_one_to_many({vpiModule, vpiInterface, vpiParameter, vpiParamAssign, vpiPort, vpiNet, vpiArrayNet, vpiTaskFunc, vpiGenScopeArray,
                               vpiContAssign, vpiVariables},
                              obj_h, [&](AST::AstNode *node) {
                                  if (node) {
                                      add_or_replace_child(current_node, node);
                                  }
                              });
            // Primitives will have the same names (like "and"), so we need to make sure we don't replace them
            visit_one_to_many({vpiPrimitive}, obj_h, [&](AST::AstNode *node) {
                if (node) {
                    current_node->children.push_back(node);
                }
            });
            current_node->children.insert(current_node->children.end(), children_after_process.begin(), children_after_process.end());

            auto it = current_node->attributes.find(UhdmAst::partial());
            if (it != current_node->attributes.end()) {
                delete it->second;
                current_node->attributes.erase(it);
            }
        } else {
            current_node = make_ast_node(AST::AST_MODULE);
            current_node->str = type;
            shared.top_nodes[current_node->str] = current_node;
            shared.current_top_node = current_node;
            current_node->attributes[UhdmAst::partial()] = AST::AstNode::mkconst_int(1, false, 1);
            visit_one_to_many({vpiTypedef}, obj_h, [&](AST::AstNode *node) {
                if (node) {
                    move_type_to_new_typedef(current_node, node);
                }
            });
            visit_one_to_many({vpiModule, vpiInterface, vpiTaskFunc, vpiParameter, vpiParamAssign, vpiPort, vpiNet, vpiArrayNet, vpiGenScopeArray,
                               vpiContAssign, vpiProcess, vpiClockingBlock, vpiAssertion},
                              obj_h, [&](AST::AstNode *node) {
                                  if (node) {
                                      if (node->type == AST::AST_ASSIGN && node->children.size() < 2)
                                          return;
                                      add_or_replace_child(current_node, node);
                                  }
                              });
        }
    } else {
        // Not a top module, create instance
        current_node = make_ast_node(AST::AST_CELL);
        std::string module_parameters;
        visit_one_to_many({vpiParamAssign}, obj_h, [&](AST::AstNode *node) {
            if (node && node->type == AST::AST_PARAMETER) {
                if (node->children[0]->type != AST::AST_CONSTANT) {
                    if (shared.top_nodes.count(type)) {
                        simplify_parameter(node, shared.top_nodes[type]);
                        log_assert(node->children[0]->type == AST::AST_CONSTANT || node->children[0]->type == AST::AST_REALVALUE);
                    }
                }
                if (shared.top_nodes.count(type)) {
                    if (!node->children[0]->str.empty())
                        module_parameters += node->str + "=" + node->children[0]->str;
                    else
                        module_parameters +=
                          node->str + "=" + std::to_string(node->children[0]->bits.size()) + "'d" + std::to_string(node->children[0]->integer);
                }
                delete node;
            }
        });
        // rename module in same way yosys do
        std::string module_name;
        if (module_parameters.size() > 60)
            module_name = "$paramod$" + sha1(module_parameters) + type;
        else if (!module_parameters.empty())
            module_name = "$paramod" + type + module_parameters;
        else
            module_name = type;
        auto module_node = shared.top_nodes[module_name];
        auto cell_instance = vpi_get(vpiCellInstance, obj_h);
        if (!module_node) {
            module_node = shared.top_nodes[type];
            if (!module_node) {
                module_node = new AST::AstNode(AST::AST_MODULE);
                module_node->str = type;
                module_node->attributes[UhdmAst::partial()] = AST::AstNode::mkconst_int(2, false, 1);
                cell_instance = 1;
                module_name = type;
            }
            if (!module_parameters.empty()) {
                module_node = module_node->clone();
            }
        }
        module_node->str = module_name;
        shared.top_nodes[module_node->str] = module_node;
        if (cell_instance) {
            module_node->attributes[ID::whitebox] = AST::AstNode::mkconst_int(1, false, 1);
        }
        visit_one_to_many({vpiParamAssign}, obj_h, [&](AST::AstNode *node) {
            if (node) {
                if (node->children[0]->type != AST::AST_CONSTANT) {
                    if (shared.top_nodes[type]) {
                        simplify_parameter(node, module_node);
                        log_assert(node->children[0]->type == AST::AST_CONSTANT || node->children[0]->type == AST::AST_REALVALUE);
                    }
                }
                auto parent_node = std::find_if(module_node->children.begin(), module_node->children.end(), [&](AST::AstNode *child) -> bool {
                    return ((child->type == AST::AST_PARAMETER) || (child->type == AST::AST_LOCALPARAM)) && child->str == node->str &&
                           // skip real parameters as they are currently not working: https://github.com/alainmarcel/Surelog/issues/1035
                           child->type != AST::AST_REALVALUE;
                });
                if (parent_node != module_node->children.end()) {
                    if ((*parent_node)->type == AST::AST_PARAMETER) {
                        if (cell_instance ||
                            (!node->children.empty() &&
                             node->children[0]->type !=
                               AST::AST_CONSTANT)) { // if cell is a blackbox or we need to simplify parameter first, left setting parameters to yosys
                            // We only want to add AST_PARASET for parameters that is different than already set
                            // to match the name yosys gives to the module.
                            // Note: this should also be applied for other (not only cell_instance) modules
                            // but as we are using part of the modules parsed by sv2v and other
                            // part by uhdm, we need to always rename module if it is parametrized,
                            // Otherwise, verilog frontend can use module parsed by uhdm and try to set
                            // parameters, but this module would be already parametrized
                            if ((node->children[0]->integer != (*parent_node)->children[0]->integer ||
                                 node->children[0]->str != (*parent_node)->children[0]->str)) {
                                node->type = AST::AST_PARASET;
                                current_node->children.push_back(node);
                            }
                        } else {
                            add_or_replace_child(module_node, node);
                        }
                    } else {
                        add_or_replace_child(module_node, node);
                    }
                } else if ((module_node->attributes.count(UhdmAst::partial()) && module_node->attributes[UhdmAst::partial()]->integer == 2)) {
                    // When module definition is not parsed by Surelog, left setting parameters to yosys
                    node->type = AST::AST_PARASET;
                    current_node->children.push_back(node);
                }
            }
        });
        // TODO: setting keep attribute probably shouldn't be needed,
        // but without this, modules that are generated in genscope are removed
        // for now lets just add this attribute
        module_node->attributes[ID::keep] = AST::AstNode::mkconst_int(1, false, 1);
        if (module_node->attributes.count(UhdmAst::partial())) {
            AST::AstNode *attr = module_node->attributes.at(UhdmAst::partial());
            if (attr->type == AST::AST_CONSTANT)
                if (attr->integer == 1) {
                    delete attr;
                    module_node->attributes.erase(UhdmAst::partial());
                }
        }
        auto typeNode = new AST::AstNode(AST::AST_CELLTYPE);
        typeNode->str = module_node->str;
        current_node->children.insert(current_node->children.begin(), typeNode);
        auto old_top = shared.current_top_node;
        shared.current_top_node = module_node;
        visit_one_to_many({vpiVariables, vpiNet, vpiArrayNet}, obj_h, [&](AST::AstNode *node) {
            if (node) {
                add_or_replace_child(module_node, node);
            }
        });
        visit_one_to_many({vpiInterface, vpiModule, vpiPort, vpiGenScopeArray}, obj_h, [&](AST::AstNode *node) {
            if (node) {
                add_or_replace_child(module_node, node);
            }
        });
        make_cell(obj_h, current_node, module_node);
        shared.current_top_node = old_top;
    }
}

void UhdmAst::process_struct_typespec()
{
    current_node = make_ast_node(AST::AST_STRUCT);
    visit_one_to_many({vpiTypespecMember}, obj_h, [&](AST::AstNode *node) {
        if (node->children.size() > 0 && node->children[0]->type == AST::AST_ENUM) {
            log_assert(node->children.size() == 1);
            log_assert(!node->children[0]->children.empty());
            log_assert(!node->children[0]->children[0]->children.empty());
            // TODO: add missing enum_type attribute
            auto range = make_range(0, 0);
            // check if single enum element is larger than 1 bit
            if (node->children[0]->children[0]->children.size() == 2) {
                range = node->children[0]->children[0]->children[1]->clone();
            }
            delete node->children[0];
            node->children.clear();
            node->children.push_back(range);
        }
        current_node->children.push_back(node);
    });
}

void UhdmAst::process_union_typespec()
{
    current_node = make_ast_node(AST::AST_UNION);
    visit_one_to_many({vpiTypespecMember}, obj_h, [&](AST::AstNode *node) {
        if (node->children.size() > 0 && node->children[0]->type == AST::AST_ENUM) {
            log_assert(node->children.size() == 1);
            log_assert(!node->children[0]->children.empty());
            log_assert(!node->children[0]->children[0]->children.empty());
            // TODO: add missing enum_type attribute
            auto range = make_range(0, 0);
            // check if single enum element is larger than 1 bit
            if (node->children[0]->children[0]->children.size() == 2) {
                range = node->children[0]->children[0]->children[1]->clone();
            }
            delete node->children[0];
            node->children.clear();
            node->children.push_back(range);
        }
        current_node->children.push_back(node);
    });
}

void UhdmAst::process_array_typespec()
{
    current_node = make_ast_node(AST::AST_WIRE);
    std::vector<AST::AstNode *> packed_ranges;
    std::vector<AST::AstNode *> unpacked_ranges;
    visit_one_to_one({vpiElemTypespec}, obj_h, [&](AST::AstNode *node) {
        if (node && node->type == AST::AST_STRUCT) {
            auto str = current_node->str;
            node->cloneInto(current_node);
            current_node->str = str;
            delete node;
        }
    });
    visit_one_to_many({vpiRange}, obj_h, [&](AST::AstNode *node) { unpacked_ranges.push_back(node); });
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges);
}

void UhdmAst::process_typespec_member()
{
    std::vector<AST::AstNode *> packed_ranges;
    std::vector<AST::AstNode *> unpacked_ranges;
    current_node = make_ast_node(AST::AST_STRUCT_ITEM);
    current_node->str = current_node->str.substr(1);
    vpiHandle typespec_h = vpi_handle(vpiTypespec, obj_h);
    int typespec_type = vpi_get(vpiType, typespec_h);
    switch (typespec_type) {
    case vpiBitTypespec:
    case vpiLogicTypespec: {
        current_node->is_logic = true;
        visit_one_to_many({vpiRange}, typespec_h, [&](AST::AstNode *node) { packed_ranges.push_back(node); });
        shared.report.mark_handled(typespec_h);
        break;
    }
    case vpiByteTypespec: {
        current_node->is_signed = true;
        packed_ranges.push_back(make_range(7, 0));
        shared.report.mark_handled(typespec_h);
        break;
    }
    case vpiShortIntTypespec: {
        current_node->is_signed = true;
        packed_ranges.push_back(make_range(15, 0));
        shared.report.mark_handled(typespec_h);
        break;
    }
    case vpiIntTypespec:
    case vpiIntegerTypespec: {
        current_node->is_signed = true;
        packed_ranges.push_back(make_range(31, 0));
        shared.report.mark_handled(typespec_h);
        break;
    }
    case vpiStructTypespec:
    case vpiUnionTypespec:
    case vpiEnumTypespec: {
        visit_one_to_one({vpiTypespec}, obj_h, [&](AST::AstNode *node) {
            if (typespec_type == vpiStructTypespec || typespec_type == vpiUnionTypespec) {
                auto str = current_node->str;
                node->cloneInto(current_node);
                current_node->str = str;
                delete node;
            } else if (typespec_type == vpiEnumTypespec) {
                current_node->children.push_back(node);
            } else {
                delete node;
            }
        });
        break;
    }
    case vpiPackedArrayTypespec:
        visit_one_to_one({vpiTypespec}, obj_h, [&](AST::AstNode *node) {
            if (node && node->type == AST::AST_STRUCT) {
                auto str = current_node->str;
                if (node->attributes.count(UhdmAst::packed_ranges())) {
                    for (auto r : node->attributes[UhdmAst::packed_ranges()]->children) {
                        packed_ranges.push_back(r->clone());
                    }
                    std::reverse(packed_ranges.begin(), packed_ranges.end());
                    node->attributes.erase(UhdmAst::packed_ranges());
                }
                if (node->attributes.count(UhdmAst::unpacked_ranges())) {
                    for (auto r : node->attributes[UhdmAst::unpacked_ranges()]->children) {
                        unpacked_ranges.push_back(r->clone());
                    }
                    node->attributes.erase(UhdmAst::unpacked_ranges());
                }
                node->cloneInto(current_node);
                current_node->str = str;
                current_node->children.insert(current_node->children.end(), packed_ranges.begin(), packed_ranges.end());
                packed_ranges.clear();
                delete node;
            } else if (node) {
                auto str = current_node->str;
                if (node->attributes.count(UhdmAst::packed_ranges())) {
                    for (auto r : node->attributes[UhdmAst::packed_ranges()]->children) {
                        packed_ranges.push_back(r->clone());
                    }
                    std::reverse(packed_ranges.begin(), packed_ranges.end());
                    node->attributes.erase(UhdmAst::packed_ranges());
                }
                if (node->attributes.count(UhdmAst::unpacked_ranges())) {
                    for (auto r : node->attributes[UhdmAst::unpacked_ranges()]->children) {
                        unpacked_ranges.push_back(r->clone());
                    }
                    node->attributes.erase(UhdmAst::unpacked_ranges());
                }
                node->cloneInto(current_node);
                current_node->str = str;
                current_node->type = AST::AST_STRUCT_ITEM;
                delete node;
            }
        });
        break;
    default: {
        const uhdm_handle *const handle = (const uhdm_handle *)typespec_h;
        const UHDM::BaseClass *const object = (const UHDM::BaseClass *)handle->object;
        report_error("%s:%d: Encountered unhandled typespec in process_typespec_member: '%s' of type '%s'\n", object->VpiFile().c_str(),
                     object->VpiLineNo(), object->VpiName().c_str(), UHDM::VpiTypeName(typespec_h).c_str());
        break;
    }
    }
    vpi_release_handle(typespec_h);
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges);
}

void UhdmAst::process_enum_typespec()
{
    current_node = make_ast_node(AST::AST_ENUM);
    visit_one_to_one({vpiTypedefAlias}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            current_node->attributes["\\enum_base_type"] = node->clone();
        }
    });
    visit_one_to_many({vpiEnumConst}, obj_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
    vpiHandle typespec_h = vpi_handle(vpiBaseTypespec, obj_h);
    if (typespec_h) {
        int typespec_type = vpi_get(vpiType, typespec_h);
        switch (typespec_type) {
        case vpiLogicTypespec: {
            current_node->is_logic = true;
            bool has_range = false;
            visit_range(typespec_h, [&](AST::AstNode *node) {
                has_range = true;
                for (auto child : current_node->children) {
                    child->children.push_back(node->clone());
                }
                delete node;
            });
            if (!has_range) // range is needed for simplify
                for (auto child : current_node->children)
                    child->children.push_back(make_ast_node(AST::AST_RANGE, {AST::AstNode::mkconst_int(0, true)}));
            shared.report.mark_handled(typespec_h);
            break;
        }
        case vpiIntTypespec:
        case vpiIntegerTypespec: {
            current_node->is_signed = true;
            shared.report.mark_handled(typespec_h);
            break;
        }
        case vpiBitTypespec: {
            bool has_range = false;
            visit_range(typespec_h, [&](AST::AstNode *node) {
                has_range = true;
                for (auto child : current_node->children) {
                    child->children.push_back(node->clone());
                }
                delete node;
            });
            if (!has_range) // range is needed for simplify
                for (auto child : current_node->children)
                    child->children.push_back(make_ast_node(AST::AST_RANGE, {AST::AstNode::mkconst_int(0, true)}));
            shared.report.mark_handled(typespec_h);
            break;
        }
        default: {
            const uhdm_handle *const handle = (const uhdm_handle *)typespec_h;
            const UHDM::BaseClass *const object = (const UHDM::BaseClass *)handle->object;
            report_error("%s:%d: Encountered unhandled typespec in process_enum_typespec: '%s' of type '%s'\n", object->VpiFile().c_str(),
                         object->VpiLineNo(), object->VpiName().c_str(), UHDM::VpiTypeName(typespec_h).c_str());
            break;
        }
        }
        vpi_release_handle(typespec_h);
    }
}

void UhdmAst::process_enum_const()
{
    current_node = make_ast_node(AST::AST_ENUM_ITEM);
    AST::AstNode *constant_node = process_value(obj_h);
    if (constant_node) {
        constant_node->filename = current_node->filename;
        constant_node->location = current_node->location;
        current_node->children.push_back(constant_node);
    }
}

void UhdmAst::process_custom_var()
{
    current_node = make_ast_node(AST::AST_WIRE);
    visit_one_to_one({vpiTypespec}, obj_h, [&](AST::AstNode *node) {
        if (node->str.empty()) {
            // anonymous typespec, move the children to variable
            current_node->type = node->type;
            copy_packed_unpacked_attribute(node, current_node);
            current_node->children = std::move(node->children);
        } else {
            auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
            wiretype_node->str = node->str;
            current_node->children.push_back(wiretype_node);
        }
        delete node;
    });
    auto type = vpi_get(vpiType, obj_h);
    if (type == vpiEnumVar || type == vpiStructVar || type == vpiUnionVar) {
        visit_default_expr(obj_h);
    }
    current_node->is_custom_type = true;
}

void UhdmAst::process_int_var()
{
    current_node = make_ast_node(AST::AST_WIRE);
    auto left_const = AST::AstNode::mkconst_int(31, true);
    auto right_const = AST::AstNode::mkconst_int(0, true);
    auto range = new AST::AstNode(AST::AST_RANGE, left_const, right_const);
    current_node->children.push_back(range);
    current_node->is_signed = true;
    visit_default_expr(obj_h);
}

void UhdmAst::process_real_var()
{
    auto module_node = find_ancestor({AST::AST_MODULE});
    auto wire_node = make_ast_node(AST::AST_WIRE);
    auto left_const = AST::AstNode::mkconst_int(63, true);
    auto right_const = AST::AstNode::mkconst_int(0, true);
    auto range = new AST::AstNode(AST::AST_RANGE, left_const, right_const);
    wire_node->children.push_back(range);
    wire_node->is_signed = true;
    module_node->children.push_back(wire_node);
    current_node = make_ast_node(AST::AST_IDENTIFIER);
    visit_default_expr(obj_h);
}

void UhdmAst::process_array_var()
{
    current_node = make_ast_node(AST::AST_WIRE);
    std::vector<AST::AstNode *> packed_ranges;
    std::vector<AST::AstNode *> unpacked_ranges;
    visit_one_to_one({vpiTypespec}, obj_h, [&](AST::AstNode *node) {
        if (node->str.empty()) {
            // anonymous typespec, move the children to variable
            current_node->type = node->type;
            current_node->children = std::move(node->children);
        } else {
            auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
            wiretype_node->str = node->str;
            current_node->children.push_back(wiretype_node);
            current_node->is_custom_type = true;
        }
        delete node;
    });
    vpiHandle itr = vpi_iterate(vpi_get(vpiType, obj_h) == vpiArrayVar ? vpiReg : vpiElement, obj_h);
    while (vpiHandle reg_h = vpi_scan(itr)) {
        if (vpi_get(vpiType, reg_h) == vpiStructVar || vpi_get(vpiType, reg_h) == vpiEnumVar) {
            visit_one_to_one({vpiTypespec}, reg_h, [&](AST::AstNode *node) {
                if (node->str.empty()) {
                    // anonymous typespec, move the children to variable
                    current_node->type = node->type;
                    current_node->children = std::move(node->children);
                } else {
                    auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
                    wiretype_node->str = node->str;
                    current_node->children.push_back(wiretype_node);
                    current_node->is_custom_type = true;
                }
                delete node;
            });
        } else if (vpi_get(vpiType, reg_h) == vpiLogicVar) {
            current_node->is_logic = true;
            visit_one_to_one({vpiTypespec}, reg_h, [&](AST::AstNode *node) {
                if (node->str.empty()) {
                    // anonymous typespec, move the children to variable
                    current_node->type = node->type;
                    current_node->children = std::move(node->children);
                } else {
                    auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
                    wiretype_node->str = node->str;
                    current_node->children.push_back(wiretype_node);
                    current_node->is_custom_type = true;
                }
                delete node;
            });
            visit_one_to_many({vpiRange}, reg_h, [&](AST::AstNode *node) { packed_ranges.push_back(node); });
        } else if (vpi_get(vpiType, reg_h) == vpiIntVar) {
            packed_ranges.push_back(make_range(31, 0));
            visit_default_expr(reg_h);
        }
        vpi_release_handle(reg_h);
    }
    vpi_release_handle(itr);
    visit_one_to_many({vpiRange}, obj_h, [&](AST::AstNode *node) { unpacked_ranges.push_back(node); });
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges);
    visit_default_expr(obj_h);
}

void UhdmAst::process_packed_array_var()
{
    current_node = make_ast_node(AST::AST_WIRE);
    std::vector<AST::AstNode *> packed_ranges;
    std::vector<AST::AstNode *> unpacked_ranges;
    visit_one_to_one({vpiTypespec}, obj_h, [&](AST::AstNode *node) {
        if (node->str.empty()) {
            // anonymous typespec, move the children to variable
            current_node->type = node->type;
            current_node->children = std::move(node->children);
        } else {
            auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
            wiretype_node->str = node->str;
            current_node->children.push_back(wiretype_node);
            current_node->is_custom_type = true;
        }
        delete node;
    });
    vpiHandle itr = vpi_iterate(vpi_get(vpiType, obj_h) == vpiArrayVar ? vpiReg : vpiElement, obj_h);
    while (vpiHandle reg_h = vpi_scan(itr)) {
        if (vpi_get(vpiType, reg_h) == vpiStructVar || vpi_get(vpiType, reg_h) == vpiEnumVar) {
            visit_one_to_one({vpiTypespec}, reg_h, [&](AST::AstNode *node) {
                if (node->str.empty()) {
                    // anonymous typespec, move the children to variable
                    current_node->type = node->type;
                    current_node->children = std::move(node->children);
                } else {
                    auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
                    wiretype_node->str = node->str;
                    current_node->children.push_back(wiretype_node);
                    current_node->is_custom_type = true;
                }
                delete node;
            });
        } else if (vpi_get(vpiType, reg_h) == vpiLogicVar) {
            current_node->is_logic = true;
            visit_one_to_one({vpiTypespec}, reg_h, [&](AST::AstNode *node) {
                if (node->str.empty()) {
                    // anonymous typespec, move the children to variable
                    current_node->type = node->type;
                    current_node->children = std::move(node->children);
                } else {
                    auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
                    wiretype_node->str = node->str;
                    current_node->children.push_back(wiretype_node);
                    current_node->is_custom_type = true;
                }
                delete node;
            });
            visit_one_to_many({vpiRange}, reg_h, [&](AST::AstNode *node) { packed_ranges.push_back(node); });
        } else if (vpi_get(vpiType, reg_h) == vpiIntVar) {
            packed_ranges.push_back(make_range(31, 0));
            visit_default_expr(reg_h);
        }
        vpi_release_handle(reg_h);
    }
    vpi_release_handle(itr);
    visit_one_to_many({vpiRange}, obj_h, [&](AST::AstNode *node) { packed_ranges.push_back(node); });
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges);
    visit_default_expr(obj_h);
}

void UhdmAst::process_param_assign()
{
    current_node = make_ast_node(AST::AST_PARAMETER);
    visit_one_to_one({vpiLhs}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            current_node->type = node->type;
            current_node->str = node->str;
            // Here we need to copy any ranges that is already present in lhs,
            // but we want to skip actual value, as it is set in rhs
            for (auto *c : node->children) {
                if (c->type != AST::AST_CONSTANT) {
                    current_node->children.push_back(c->clone());
                }
            }
            copy_packed_unpacked_attribute(node, current_node);
            if (node->attributes.count(UhdmAst::is_imported())) {
                current_node->attributes[UhdmAst::is_imported()] = node->attributes[UhdmAst::is_imported()]->clone();
            }
            current_node->is_custom_type = node->is_custom_type;
            shared.param_types[current_node->str] = shared.param_types[node->str];
            delete node;
        }
    });
    visit_one_to_one({vpiRhs}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            if (node->children.size() > 1 && (node->children[1]->type == AST::AST_PARAMETER || node->children[1]->type == AST::AST_LOCALPARAM)) {
                node->children[1]->type = AST::AST_IDENTIFIER;
            }
            current_node->children.insert(current_node->children.begin(), node);
        }
    });
}

void UhdmAst::process_cont_assign_var_init()
{
    current_node = make_ast_node(AST::AST_INITIAL);
    auto block_node = make_ast_node(AST::AST_BLOCK);
    auto assign_node = make_ast_node(AST::AST_ASSIGN_LE);
    block_node->children.push_back(assign_node);
    current_node->children.push_back(block_node);

    visit_one_to_one({vpiLhs, vpiRhs}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            if (node->type == AST::AST_WIRE || node->type == AST::AST_PARAMETER || node->type == AST::AST_LOCALPARAM) {
                assign_node->children.push_back(new AST::AstNode(AST::AST_IDENTIFIER));
                assign_node->children.back()->str = node->str;
            } else {
                assign_node->children.push_back(node);
            }
        }
    });
}

void UhdmAst::process_cont_assign_net()
{
    current_node = make_ast_node(AST::AST_ASSIGN);

    visit_one_to_one({vpiLhs, vpiRhs}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            if (node->type == AST::AST_WIRE || node->type == AST::AST_PARAMETER || node->type == AST::AST_LOCALPARAM) {
                current_node->children.push_back(new AST::AstNode(AST::AST_IDENTIFIER));
                current_node->children.back()->str = node->str;
            } else {
                current_node->children.push_back(node);
            }
        }
    });
}

void UhdmAst::process_cont_assign()
{
    auto net_decl_assign = vpi_get(vpiNetDeclAssign, obj_h);
    vpiHandle node_lhs_h = vpi_handle(vpiLhs, obj_h);
    auto lhs_net_type = vpi_get(vpiNetType, node_lhs_h);
    vpi_release_handle(node_lhs_h);

    // Check if lhs is a subtype of a net
    bool isNet;
    if (lhs_net_type >= vpiWire && lhs_net_type <= vpiUwire)
        isNet = true;
    else
        // lhs is a variable
        isNet = false;
    if (net_decl_assign && !isNet)
        process_cont_assign_var_init();
    else
        process_cont_assign_net();
}

void UhdmAst::process_assignment()
{
    auto type = vpi_get(vpiBlocking, obj_h) == 1 ? AST::AST_ASSIGN_EQ : AST::AST_ASSIGN_LE;
    current_node = make_ast_node(type);
    visit_one_to_one({vpiLhs, vpiRhs}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            if (node->type == AST::AST_PARAMETER || node->type == AST::AST_LOCALPARAM) {
                node->type = AST::AST_IDENTIFIER;
            }
            current_node->children.push_back(node);
        }
    });
    if (current_node->children.size() == 1 && current_node->children[0]->type == AST::AST_WIRE) {
        auto top_node = find_ancestor({AST::AST_MODULE});
        if (!top_node)
            return;
        top_node->children.push_back(current_node->children[0]->clone());
        current_node = nullptr;
    }
}

void UhdmAst::process_packed_array_net()
{
    std::vector<AST::AstNode *> packed_ranges;
    std::vector<AST::AstNode *> unpacked_ranges;
    current_node = make_ast_node(AST::AST_WIRE);
    visit_one_to_many({vpiElement}, obj_h, [&](AST::AstNode *node) {
        if (node && GetSize(node->children) == 1)
            current_node->children.push_back(node->children[0]);
        current_node->is_custom_type = node->is_custom_type;
    });
    visit_one_to_many({vpiRange}, obj_h, [&](AST::AstNode *node) { packed_ranges.push_back(node); });
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges);
}

void UhdmAst::process_array_net(const UHDM::BaseClass *object)
{
    current_node = make_ast_node(AST::AST_WIRE);
    vpiHandle itr = vpi_iterate(vpiNet, obj_h);
    std::vector<AST::AstNode *> packed_ranges;
    std::vector<AST::AstNode *> unpacked_ranges;
    while (vpiHandle net_h = vpi_scan(itr)) {
        auto net_type = vpi_get(vpiType, net_h);
        if (net_type == vpiLogicNet) {
            current_node->is_logic = true;
            current_node->is_signed = vpi_get(vpiSigned, net_h);
            vpiHandle typespec_h = vpi_handle(vpiTypespec, net_h);
            if (!typespec_h) {
                typespec_h = vpi_handle(vpiTypespec, obj_h);
            }
            if (typespec_h) {
                visit_one_to_many({vpiRange}, typespec_h, [&](AST::AstNode *node) { packed_ranges.push_back(node); });
                vpi_release_handle(typespec_h);
            } else {
                visit_one_to_many({vpiRange}, net_h, [&](AST::AstNode *node) { packed_ranges.push_back(node); });
            }
            shared.report.mark_handled(net_h);
        } else if (net_type == vpiStructNet) {
            visit_one_to_one({vpiTypespec}, net_h, [&](AST::AstNode *node) {
                if (node->str.empty()) {
                    // anonymous typespec, move the children to variable
                    current_node->type = node->type;
                    current_node->children = std::move(node->children);
                } else {
                    auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
                    wiretype_node->str = node->str;
                    current_node->children.push_back(wiretype_node);
                    current_node->is_custom_type = true;
                }
                delete node;
            });
        }
        vpi_release_handle(net_h);
    }
    vpi_release_handle(itr);
    visit_one_to_many({vpiRange}, obj_h, [&](AST::AstNode *node) { unpacked_ranges.push_back(node); });
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges);
}

void UhdmAst::process_package()
{
    current_node = make_ast_node(AST::AST_PACKAGE);
    shared.current_top_node = current_node;
    visit_one_to_many({vpiTypedef}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            move_type_to_new_typedef(current_node, node);
        }
    });
    visit_one_to_many({vpiParameter, vpiParamAssign}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            node->str = strip_package_name(node->str);
            for (auto c : node->children) {
                c->str = strip_package_name(c->str);
            }
            add_or_replace_child(current_node, node);
        }
    });
    visit_one_to_many({vpiTaskFunc}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            current_node->children.push_back(node);
        }
    });
}

void UhdmAst::process_interface()
{
    std::string type = vpi_get_str(vpiDefName, obj_h);
    std::string name = vpi_get_str(vpiName, obj_h) ? vpi_get_str(vpiName, obj_h) : type;
    sanitize_symbol_name(type);
    sanitize_symbol_name(name);
    AST::AstNode *elaboratedInterface;
    // Check if we have encountered this object before
    if (shared.top_nodes.find(type) != shared.top_nodes.end()) {
        // Was created before, fill missing
        elaboratedInterface = shared.top_nodes[type];
        visit_one_to_many({vpiPort}, obj_h, [&](AST::AstNode *node) {
            if (node) {
                add_or_replace_child(elaboratedInterface, node);
            }
        });
    } else {
        // Encountered for the first time
        elaboratedInterface = new AST::AstNode(AST::AST_INTERFACE);
        elaboratedInterface->str = name;
        visit_one_to_many({vpiNet, vpiPort, vpiModport}, obj_h, [&](AST::AstNode *node) {
            if (node) {
                add_or_replace_child(elaboratedInterface, node);
            }
        });
    }
    shared.top_nodes[elaboratedInterface->str] = elaboratedInterface;
    if (name != type) {
        // Not a top module, create instance
        current_node = make_ast_node(AST::AST_CELL);
        make_cell(obj_h, current_node, elaboratedInterface);
    } else {
        current_node = elaboratedInterface;
    }
}

void UhdmAst::process_modport()
{
    current_node = make_ast_node(AST::AST_MODPORT);
    visit_one_to_many({vpiIODecl}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            current_node->children.push_back(node);
        }
    });
}

void UhdmAst::process_io_decl()
{
    current_node = nullptr;
    std::vector<AST::AstNode *> packed_ranges;   // comes before wire name
    std::vector<AST::AstNode *> unpacked_ranges; // comes after wire name
    visit_one_to_one({vpiExpr}, obj_h, [&](AST::AstNode *node) { current_node = node; });
    if (current_node == nullptr) {
        current_node = make_ast_node(AST::AST_MODPORTMEMBER);
        visit_one_to_many({vpiRange}, obj_h, [&](AST::AstNode *node) { unpacked_ranges.push_back(node); });
    }
    std::reverse(unpacked_ranges.begin(), unpacked_ranges.end());

    visit_one_to_one({vpiTypedef}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            if (!node->str.empty()) {
                auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
                wiretype_node->str = node->str;
                // wiretype needs to be 1st node (if port have also another range nodes)
                current_node->children.insert(current_node->children.begin(), wiretype_node);
                current_node->is_custom_type = true;
            } else {
                // anonymous typedef, just move children
                for (auto child : node->children) {
                    current_node->children.push_back(child->clone());
                }
                if (node->attributes.count(UhdmAst::packed_ranges())) {
                    for (auto r : node->attributes[UhdmAst::packed_ranges()]->children) {
                        packed_ranges.push_back(r->clone());
                    }
                }
                if (node->attributes.count(UhdmAst::unpacked_ranges())) {
                    for (auto r : node->attributes[UhdmAst::unpacked_ranges()]->children) {
                        unpacked_ranges.push_back(r->clone());
                    }
                }
                current_node->is_logic = node->is_logic;
                current_node->is_reg = node->is_reg;
            }
            delete node;
        }
    });
    if (const int n = vpi_get(vpiDirection, obj_h)) {
        if (n == vpiInput) {
            current_node->is_input = true;
        } else if (n == vpiOutput) {
            current_node->is_output = true;
        } else if (n == vpiInout) {
            current_node->is_input = true;
            current_node->is_output = true;
        }
    }
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges, false);
}

void UhdmAst::process_always()
{
    current_node = make_ast_node(AST::AST_ALWAYS);
    visit_one_to_one({vpiStmt}, obj_h, [&](AST::AstNode *node) {
        AST::AstNode *block = nullptr;
        if (node && node->type != AST::AST_BLOCK) {
            block = new AST::AstNode(AST::AST_BLOCK, node);
        } else {
            block = node;
        }
        current_node->children.push_back(block);
    });
    switch (vpi_get(vpiAlwaysType, obj_h)) {
    case vpiAlwaysComb:
        current_node->attributes[ID::always_comb] = AST::AstNode::mkconst_int(1, false);
        break;
    case vpiAlwaysFF:
        current_node->attributes[ID::always_ff] = AST::AstNode::mkconst_int(1, false);
        break;
    case vpiAlwaysLatch:
        current_node->attributes[ID::always_latch] = AST::AstNode::mkconst_int(1, false);
        break;
    default:
        break;
    }
}

void UhdmAst::process_event_control(const UHDM::BaseClass *object)
{
    current_node = make_ast_node(AST::AST_BLOCK);
    visit_one_to_one({vpiCondition}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            auto process_node = find_ancestor({AST::AST_ALWAYS});
            if (!process_node) {
                log_error("%s:%d: Currently supports only event control stmts inside 'always'\n", object->VpiFile().c_str(), object->VpiLineNo());
            }
            process_node->children.push_back(node);
        }
        // is added inside vpiOperation
    });
    visit_one_to_one({vpiStmt}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            current_node->children.push_back(node);
        }
    });
}

void UhdmAst::process_initial()
{
    current_node = make_ast_node(AST::AST_INITIAL);
    visit_one_to_one({vpiStmt}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            if (node->type != AST::AST_BLOCK) {
                auto block_node = make_ast_node(AST::AST_BLOCK);
                block_node->children.push_back(node);
                node = block_node;
            }
            current_node->children.push_back(node);
        }
    });
}

void UhdmAst::process_begin(bool is_named)
{
    current_node = make_ast_node(AST::AST_BLOCK);
    // TODO: find out how to set VERILOG_FRONTEND::sv_mode to true
    // simplify checks if sv_mode is set to ture when wire is declared inside unnamed block
    if (is_named) {
        visit_one_to_many({vpiVariables}, obj_h, [&](AST::AstNode *node) {
            if (node) {
                current_node->children.push_back(node);
            }
        });
    }
    visit_one_to_many({vpiStmt}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            if ((node->type == AST::AST_ASSIGN_EQ || node->type == AST::AST_ASSIGN_LE) && node->children.size() == 1) {
                auto func_node = find_ancestor({AST::AST_FUNCTION, AST::AST_TASK});
                if (!func_node)
                    return;
                auto wire_node = new AST::AstNode(AST::AST_WIRE);
                wire_node->type = AST::AST_WIRE;
                wire_node->str = node->children[0]->str;
                func_node->children.push_back(wire_node);
            } else {
                current_node->children.push_back(node);
            }
        }
    });
}

void UhdmAst::process_operation(const UHDM::BaseClass *object)
{
    auto operation = vpi_get(vpiOpType, obj_h);
    switch (operation) {
    case vpiStreamRLOp:
        process_stream_op();
        break;
    case vpiEventOrOp:
    case vpiListOp:
        process_list_op();
        break;
    case vpiCastOp:
        process_cast_op();
        break;
    case vpiInsideOp:
        process_inside_op();
        break;
    case vpiAssignmentPatternOp:
        process_assignment_pattern_op();
        break;
    case vpiWildEqOp:
    case vpiWildNeqOp: {
        report_error("%s:%d: Wildcard operators are not supported yet\n", object->VpiFile().c_str(), object->VpiLineNo());
        break;
    }
    default: {
        current_node = make_ast_node(AST::AST_NONE);
        visit_one_to_many({vpiOperand}, obj_h, [&](AST::AstNode *node) {
            if (node) {
                current_node->children.push_back(node);
            }
        });
        switch (operation) {
        case vpiMinusOp:
            current_node->type = AST::AST_NEG;
            break;
        case vpiPlusOp:
            current_node->type = AST::AST_POS;
            break;
        case vpiPosedgeOp:
            current_node->type = AST::AST_POSEDGE;
            break;
        case vpiNegedgeOp:
            current_node->type = AST::AST_NEGEDGE;
            break;
        case vpiUnaryAndOp:
            current_node->type = AST::AST_REDUCE_AND;
            break;
        case vpiUnaryOrOp:
            current_node->type = AST::AST_REDUCE_OR;
            break;
        case vpiUnaryXorOp:
            current_node->type = AST::AST_REDUCE_XOR;
            break;
        case vpiUnaryXNorOp:
            current_node->type = AST::AST_REDUCE_XNOR;
            break;
        case vpiUnaryNandOp: {
            current_node->type = AST::AST_REDUCE_AND;
            auto not_node = new AST::AstNode(AST::AST_LOGIC_NOT, current_node);
            current_node = not_node;
            break;
        }
        case vpiUnaryNorOp: {
            current_node->type = AST::AST_REDUCE_OR;
            auto not_node = new AST::AstNode(AST::AST_LOGIC_NOT, current_node);
            current_node = not_node;
            break;
        }
        case vpiBitNegOp:
            current_node->type = AST::AST_BIT_NOT;
            break;
        case vpiBitAndOp:
            current_node->type = AST::AST_BIT_AND;
            break;
        case vpiBitOrOp:
            current_node->type = AST::AST_BIT_OR;
            break;
        case vpiBitXorOp:
            current_node->type = AST::AST_BIT_XOR;
            break;
        case vpiBitXnorOp:
            current_node->type = AST::AST_BIT_XNOR;
            break;
        case vpiLShiftOp:
            current_node->type = AST::AST_SHIFT_LEFT;
            log_assert(current_node->children.size() == 2);
            mark_as_unsigned(current_node->children[1], object);
            break;
        case vpiRShiftOp:
            current_node->type = AST::AST_SHIFT_RIGHT;
            log_assert(current_node->children.size() == 2);
            mark_as_unsigned(current_node->children[1], object);
            break;
        case vpiNotOp:
            current_node->type = AST::AST_LOGIC_NOT;
            break;
        case vpiLogAndOp:
            current_node->type = AST::AST_LOGIC_AND;
            break;
        case vpiLogOrOp:
            current_node->type = AST::AST_LOGIC_OR;
            break;
        case vpiEqOp:
            current_node->type = AST::AST_EQ;
            break;
        case vpiNeqOp:
            current_node->type = AST::AST_NE;
            break;
        case vpiCaseEqOp:
            current_node->type = AST::AST_EQX;
            break;
        case vpiCaseNeqOp:
            current_node->type = AST::AST_NEX;
            break;
        case vpiGtOp:
            current_node->type = AST::AST_GT;
            break;
        case vpiGeOp:
            current_node->type = AST::AST_GE;
            break;
        case vpiLtOp:
            current_node->type = AST::AST_LT;
            break;
        case vpiLeOp:
            current_node->type = AST::AST_LE;
            break;
        case vpiSubOp:
            current_node->type = AST::AST_SUB;
            if (!current_node->children.empty() && current_node->children[0]->type == AST::AST_LOCALPARAM) {
                current_node->children[0]->type = AST::AST_IDENTIFIER;
            }
            break;
        case vpiAddOp:
            current_node->type = AST::AST_ADD;
            break;
        case vpiMultOp:
            current_node->type = AST::AST_MUL;
            break;
        case vpiDivOp:
            current_node->type = AST::AST_DIV;
            break;
        case vpiModOp:
            current_node->type = AST::AST_MOD;
            break;
        case vpiArithLShiftOp:
            current_node->type = AST::AST_SHIFT_SLEFT;
            log_assert(current_node->children.size() == 2);
            mark_as_unsigned(current_node->children[1], object);
            break;
        case vpiArithRShiftOp:
            current_node->type = AST::AST_SHIFT_SRIGHT;
            log_assert(current_node->children.size() == 2);
            mark_as_unsigned(current_node->children[1], object);
            break;
        case vpiPowerOp:
            current_node->type = AST::AST_POW;
            break;
        case vpiPostIncOp: {
            // TODO: Make this an actual post-increment op (currently it's a pre-increment)
            log_warning("%s:%d: Post-incrementation operations are handled as pre-incrementation.\n", object->VpiFile().c_str(), object->VpiLineNo());
            [[fallthrough]];
        }
        case vpiPreIncOp: {
            current_node->type = AST::AST_ASSIGN_EQ;
            auto id = current_node->children[0]->clone();
            auto add_node = new AST::AstNode(AST::AST_ADD, id, AST::AstNode::mkconst_int(1, true));
            add_node->filename = current_node->filename;
            add_node->location = current_node->location;
            current_node->children.push_back(add_node);
            break;
        }
        case vpiPostDecOp: {
            // TODO: Make this an actual post-decrement op (currently it's a pre-decrement)
            log_warning("%s:%d: Post-decrementation operations are handled as pre-decrementation.\n", object->VpiFile().c_str(), object->VpiLineNo());
            [[fallthrough]];
        }
        case vpiPreDecOp: {
            current_node->type = AST::AST_ASSIGN_EQ;
            auto id = current_node->children[0]->clone();
            auto add_node = new AST::AstNode(AST::AST_SUB, id, AST::AstNode::mkconst_int(1, true));
            add_node->filename = current_node->filename;
            add_node->location = current_node->location;
            current_node->children.push_back(add_node);
            break;
        }
        case vpiConditionOp:
            current_node->type = AST::AST_TERNARY;
            break;
        case vpiConcatOp: {
            current_node->type = AST::AST_CONCAT;
            std::reverse(current_node->children.begin(), current_node->children.end());
            break;
        }
        case vpiMultiConcatOp:
        case vpiMultiAssignmentPatternOp:
            current_node->type = AST::AST_REPLICATE;
            break;
        case vpiAssignmentOp:
            current_node->type = AST::AST_ASSIGN_EQ;
            break;
        case vpiStreamLROp: {
            auto concat_node = current_node->children.back();
            current_node->children.pop_back();
            delete current_node;
            current_node = concat_node;
            break;
        }
        case vpiNullOp: {
            delete current_node;
            current_node = nullptr;
            break;
        }
        case vpiMinTypMaxOp: {
            // ignore min and max and set only typ
            log_assert(current_node->children.size() == 3);
            auto tmp = current_node->children[1]->clone();
            delete current_node;
            current_node = tmp;
            break;
        }
        default: {
            delete current_node;
            current_node = nullptr;
            report_error("%s:%d: Encountered unhandled operation type %d\n", object->VpiFile().c_str(), object->VpiLineNo(), operation);
        }
        }
    }
    }
}

void UhdmAst::process_stream_op()
{
    // Create a for loop that does what a streaming operator would do
    auto block_node = find_ancestor({AST::AST_BLOCK, AST::AST_ALWAYS, AST::AST_INITIAL});
    auto process_node = find_ancestor({AST::AST_ALWAYS, AST::AST_INITIAL});
    auto module_node = find_ancestor({AST::AST_MODULE, AST::AST_FUNCTION, AST::AST_PACKAGE});
    log_assert(module_node);
    if (!process_node) {
        if (module_node->type != AST::AST_FUNCTION) {
            // Create a @* always block
            process_node = make_ast_node(AST::AST_ALWAYS);
            module_node->children.push_back(process_node);
            block_node = make_ast_node(AST::AST_BLOCK);
            process_node->children.push_back(block_node);
        } else {
            // Create only block
            block_node = make_ast_node(AST::AST_BLOCK);
            module_node->children.push_back(block_node);
        }
    }

    auto loop_id = shared.next_loop_id();
    auto loop_counter =
      make_ast_node(AST::AST_WIRE, {make_ast_node(AST::AST_RANGE, {AST::AstNode::mkconst_int(31, false), AST::AstNode::mkconst_int(0, false)})});
    loop_counter->is_reg = true;
    loop_counter->is_signed = true;
    loop_counter->str = "\\loop" + std::to_string(loop_id) + "::i";
    module_node->children.insert(module_node->children.end() - 1, loop_counter);
    auto loop_counter_ident = make_ast_node(AST::AST_IDENTIFIER);
    loop_counter_ident->str = loop_counter->str;

    auto lhs_node = find_ancestor({AST::AST_ASSIGN, AST::AST_ASSIGN_EQ, AST::AST_ASSIGN_LE})->children[0];
    // Temp var to allow concatenation
    AST::AstNode *temp_var = nullptr;
    AST::AstNode *bits_call = nullptr;
    if (lhs_node->type == AST::AST_WIRE) {
        module_node->children.insert(module_node->children.begin(), lhs_node->clone());
        temp_var = lhs_node->clone(); // if we already have wire as lhs, we want to create the same wire for temp_var
        lhs_node->delete_children();
        lhs_node->type = AST::AST_IDENTIFIER;
        bits_call = make_ast_node(AST::AST_FCALL, {lhs_node->clone()});
        bits_call->str = "\\$bits";
    } else {
        // otherwise, we need to calculate size using bits fcall
        bits_call = make_ast_node(AST::AST_FCALL, {lhs_node->clone()});
        bits_call->str = "\\$bits";
        temp_var =
          make_ast_node(AST::AST_WIRE, {make_ast_node(AST::AST_RANGE, {make_ast_node(AST::AST_SUB, {bits_call, AST::AstNode::mkconst_int(1, false)}),
                                                                       AST::AstNode::mkconst_int(0, false)})});
    }

    temp_var->str = "\\loop" + std::to_string(loop_id) + "::temp";
    module_node->children.insert(module_node->children.end() - 1, temp_var);
    auto temp_var_ident = make_ast_node(AST::AST_IDENTIFIER);
    temp_var_ident->str = temp_var->str;
    auto temp_assign = make_ast_node(AST::AST_ASSIGN_EQ, {temp_var_ident});
    block_node->children.push_back(temp_assign);

    // Assignment in the loop's block
    auto assign_node = make_ast_node(AST::AST_ASSIGN_EQ, {lhs_node->clone(), temp_var_ident->clone()});
    AST::AstNode *slice_size = nullptr; // First argument in streaming op
    visit_one_to_many({vpiOperand}, obj_h, [&](AST::AstNode *node) {
        if (!slice_size && node->type == AST::AST_CONSTANT) {
            slice_size = node;
        } else {
            temp_assign->children.push_back(node);
        }
    });
    if (!slice_size) {
        slice_size = AST::AstNode::mkconst_int(1, true);
    }

    // Initialization of the loop counter to 0
    auto init_stmt = make_ast_node(AST::AST_ASSIGN_EQ, {loop_counter_ident, AST::AstNode::mkconst_int(0, true)});

    // Loop condition (loop counter < $bits(RHS))
    auto cond_stmt =
      make_ast_node(AST::AST_LE, {loop_counter_ident->clone(), make_ast_node(AST::AST_SUB, {bits_call->clone(), slice_size->clone()})});

    // Increment loop counter
    auto inc_stmt =
      make_ast_node(AST::AST_ASSIGN_EQ, {loop_counter_ident->clone(), make_ast_node(AST::AST_ADD, {loop_counter_ident->clone(), slice_size})});

    // Range on the LHS of the assignment
    auto lhs_range = make_ast_node(AST::AST_RANGE);
    auto lhs_selfsz = make_ast_node(
      AST::AST_SELFSZ, {make_ast_node(AST::AST_SUB, {make_ast_node(AST::AST_SUB, {bits_call->clone(), AST::AstNode::mkconst_int(1, true)}),
                                                     loop_counter_ident->clone()})});
    lhs_range->children.push_back(make_ast_node(AST::AST_ADD, {lhs_selfsz, AST::AstNode::mkconst_int(0, true)}));
    lhs_range->children.push_back(
      make_ast_node(AST::AST_SUB, {make_ast_node(AST::AST_ADD, {lhs_selfsz->clone(), AST::AstNode::mkconst_int(1, true)}), slice_size->clone()}));

    // Range on the RHS of the assignment
    auto rhs_range = make_ast_node(AST::AST_RANGE);
    auto rhs_selfsz = make_ast_node(AST::AST_SELFSZ, {loop_counter_ident->clone()});
    rhs_range->children.push_back(
      make_ast_node(AST::AST_SUB, {make_ast_node(AST::AST_ADD, {rhs_selfsz, slice_size->clone()}), AST::AstNode::mkconst_int(1, true)}));
    rhs_range->children.push_back(make_ast_node(AST::AST_ADD, {rhs_selfsz->clone(), AST::AstNode::mkconst_int(0, true)}));

    // Put ranges on the sides of the assignment
    assign_node->children[0]->children.push_back(lhs_range);
    assign_node->children[1]->children.push_back(rhs_range);

    // Putting the loop together
    auto loop_node = make_ast_node(AST::AST_FOR);
    loop_node->str = "$loop" + std::to_string(loop_id);
    loop_node->children.push_back(init_stmt);
    loop_node->children.push_back(cond_stmt);
    loop_node->children.push_back(inc_stmt);
    loop_node->children.push_back(make_ast_node(AST::AST_BLOCK, {assign_node}));
    loop_node->children[3]->str = "\\stream_op_block" + std::to_string(loop_id);

    block_node->children.push_back(make_ast_node(AST::AST_BLOCK, {loop_node}));

    // Do not create a node
    shared.report.mark_handled(obj_h);
}

void UhdmAst::process_list_op()
{
    // Add all operands as children of process node
    if (auto parent_node = find_ancestor({AST::AST_ALWAYS, AST::AST_COND})) {
        visit_one_to_many({vpiOperand}, obj_h, [&](AST::AstNode *node) {
            // add directly to process/cond node
            if (node) {
                parent_node->children.push_back(node);
            }
        });
    }
    // Do not create a node
    shared.report.mark_handled(obj_h);
}

void UhdmAst::process_cast_op()
{
    current_node = make_ast_node(AST::AST_NONE);
    visit_one_to_many({vpiOperand}, obj_h, [&](AST::AstNode *node) {
        node->cloneInto(current_node);
        delete node;
    });
    vpiHandle typespec_h = vpi_handle(vpiTypespec, obj_h);
    shared.report.mark_handled(typespec_h);
    vpi_release_handle(typespec_h);
}

void UhdmAst::process_inside_op()
{
    current_node = make_ast_node(AST::AST_EQ);
    AST::AstNode *lhs = nullptr;
    visit_one_to_many({vpiOperand}, obj_h, [&](AST::AstNode *node) {
        if (!lhs) {
            lhs = node;
        }
        if (current_node->children.size() < 2) {
            current_node->children.push_back(node);
        } else {
            auto or_node = new AST::AstNode(AST::AST_LOGIC_OR);
            or_node->filename = current_node->filename;
            or_node->location = current_node->location;
            auto eq_node = new AST::AstNode(AST::AST_EQ);
            eq_node->filename = current_node->filename;
            eq_node->location = current_node->location;
            or_node->children.push_back(current_node);
            or_node->children.push_back(eq_node);
            eq_node->children.push_back(lhs->clone());
            eq_node->children.push_back(node);
            current_node = or_node;
        }
    });
}

void UhdmAst::process_assignment_pattern_op()
{
    current_node = make_ast_node(AST::AST_CONCAT);
    if (auto param_node = find_ancestor({AST::AST_PARAMETER, AST::AST_LOCALPARAM})) {
        std::map<size_t, AST::AstNode *> ordered_children;
        visit_one_to_many({vpiOperand}, obj_h, [&](AST::AstNode *node) {
            if (node->type == AST::AST_ASSIGN || node->type == AST::AST_ASSIGN_EQ || node->type == AST::AST_ASSIGN_LE) {
                // Find at what position in the concat should we place this node
                auto key = node->children[0]->str;
                key = key.substr(key.find('.') + 1);
                auto param_type = shared.param_types[param_node->str];
                if (!param_type) {
                    log_error("Couldn't find parameter type for node: %s\n", param_node->str.c_str());
                }
                size_t pos =
                  std::find_if(param_type->children.begin(), param_type->children.end(), [key](AST::AstNode *child) { return child->str == key; }) -
                  param_type->children.begin();
                ordered_children.insert(std::make_pair(pos, node->children[1]->clone()));
            } else {
                current_node->children.push_back(node);
            }
        });
        for (auto p : ordered_children) {
            current_node->children.push_back(p.second);
        }
        std::reverse(current_node->children.begin(), current_node->children.end());
        return;
    }
    auto assign_node = find_ancestor({AST::AST_ASSIGN, AST::AST_ASSIGN_EQ, AST::AST_ASSIGN_LE});

    auto proc_node =
      find_ancestor({AST::AST_BLOCK, AST::AST_GENBLOCK, AST::AST_ALWAYS, AST::AST_INITIAL, AST::AST_MODULE, AST::AST_PACKAGE, AST::AST_CELL});
    if (proc_node && proc_node->type == AST::AST_CELL && shared.top_nodes.count(proc_node->children[0]->str)) {
        proc_node = shared.top_nodes[proc_node->children[0]->str];
    }
    std::vector<AST::AstNode *> assignments;
    visit_one_to_many({vpiOperand}, obj_h, [&](AST::AstNode *node) {
        if (node->type == AST::AST_ASSIGN || node->type == AST::AST_ASSIGN_EQ || node->type == AST::AST_ASSIGN_LE) {
            assignments.push_back(node);
        } else {
            current_node->children.push_back(node);
        }
    });
    std::reverse(current_node->children.begin(), current_node->children.end());
    if (!assignments.empty()) {
        if (current_node->children.empty()) {
            delete assign_node->children[0];
            assign_node->children[0] = assignments[0]->children[0];
            current_node = assignments[0]->children[1];
            assignments[0]->children.clear();
            delete assignments[0];
            proc_node->children.insert(proc_node->children.end(), assignments.begin() + 1, assignments.end());
        } else {
            proc_node->children.insert(proc_node->children.end(), assignments.begin(), assignments.end());
        }
    }
}

void UhdmAst::process_bit_select()
{
    current_node = make_ast_node(AST::AST_IDENTIFIER);
    visit_one_to_one({vpiIndex}, obj_h, [&](AST::AstNode *node) {
        auto range_node = new AST::AstNode(AST::AST_RANGE, node);
        range_node->filename = current_node->filename;
        range_node->location = current_node->location;
        current_node->children.push_back(range_node);
    });
}

void UhdmAst::process_part_select()
{
    current_node = make_ast_node(AST::AST_IDENTIFIER);
    vpiHandle parent_h = vpi_handle(vpiParent, obj_h);
    current_node->str = get_name(parent_h);
    vpi_release_handle(parent_h);
    auto range_node = new AST::AstNode(AST::AST_RANGE);
    range_node->filename = current_node->filename;
    range_node->location = current_node->location;
    visit_one_to_one({vpiLeftRange, vpiRightRange}, obj_h, [&](AST::AstNode *node) { range_node->children.push_back(node); });
    current_node->children.push_back(range_node);
}

void UhdmAst::process_indexed_part_select()
{
    current_node = make_ast_node(AST::AST_IDENTIFIER);
    vpiHandle parent_h = vpi_handle(vpiParent, obj_h);
    current_node->str = get_name(parent_h);
    vpi_release_handle(parent_h);
    // TODO: check if there are other types, for now only handle 1 and 2 (+: and -:)
    auto indexed_part_select_type = vpi_get(vpiIndexedPartSelectType, obj_h) == 1 ? AST::AST_ADD : AST::AST_SUB;
    auto range_node = new AST::AstNode(AST::AST_RANGE);
    range_node->filename = current_node->filename;
    range_node->location = current_node->location;
    visit_one_to_one({vpiBaseExpr}, obj_h, [&](AST::AstNode *node) { range_node->children.push_back(node); });
    visit_one_to_one({vpiWidthExpr}, obj_h, [&](AST::AstNode *node) {
        auto right_range_node = new AST::AstNode(indexed_part_select_type);
        right_range_node->children.push_back(range_node->children[0]->clone());
        right_range_node->children.push_back(node);
        auto sub = new AST::AstNode(indexed_part_select_type == AST::AST_ADD ? AST::AST_SUB : AST::AST_ADD);
        sub->children.push_back(right_range_node);
        sub->children.push_back(AST::AstNode::mkconst_int(1, false, 1));
        range_node->children.push_back(sub);
        // range_node->children.push_back(right_range_node);
    });
    if (indexed_part_select_type == AST::AST_ADD) {
        std::reverse(range_node->children.begin(), range_node->children.end());
    }
    current_node->children.push_back(range_node);
}

void UhdmAst::process_if_else()
{
    current_node = make_ast_node(AST::AST_CASE);
    visit_one_to_one({vpiCondition}, obj_h, [&](AST::AstNode *node) {
        if (!node) {
            log_error("Couldn't find node in if stmt. This can happend if unsupported '$value$plusargs' function is used inside if.\n");
        }
        auto reduce_node = new AST::AstNode(AST::AST_REDUCE_BOOL, node);
        current_node->children.push_back(reduce_node);
    });
    // If true:
    auto *condition = new AST::AstNode(AST::AST_COND);
    auto *constant = AST::AstNode::mkconst_int(1, false, 1);
    condition->children.push_back(constant);
    visit_one_to_one({vpiStmt}, obj_h, [&](AST::AstNode *node) {
        auto *statements = new AST::AstNode(AST::AST_BLOCK);
        statements->children.push_back(node);
        condition->children.push_back(statements);
    });
    current_node->children.push_back(condition);
    // Else:
    if (vpi_get(vpiType, obj_h) == vpiIfElse) {
        auto *condition = new AST::AstNode(AST::AST_COND);
        auto *elseBlock = new AST::AstNode(AST::AST_DEFAULT);
        condition->children.push_back(elseBlock);
        visit_one_to_one({vpiElseStmt}, obj_h, [&](AST::AstNode *node) {
            auto *statements = new AST::AstNode(AST::AST_BLOCK);
            statements->children.push_back(node);
            condition->children.push_back(statements);
        });
        current_node->children.push_back(condition);
    }
}

void UhdmAst::process_for()
{
    current_node = make_ast_node(AST::AST_FOR);
    auto loop = current_node;
    auto loop_id = shared.next_loop_id();
    current_node->str = "$loop" + std::to_string(loop_id);
    visit_one_to_many({vpiForInitStmt}, obj_h, [&](AST::AstNode *node) {
        if (node->type == AST::AST_ASSIGN_LE)
            node->type = AST::AST_ASSIGN_EQ;
        auto lhs = node->children[0];
        if (lhs->type == AST::AST_WIRE) {
            current_node = make_ast_node(AST::AST_BLOCK);
            current_node->str = "$fordecl_block" + std::to_string(loop_id);
            auto *wire = lhs->clone();
            wire->is_reg = true;
            current_node->children.push_back(wire);
            lhs->type = AST::AST_IDENTIFIER;
            lhs->is_signed = false;
            lhs->delete_children();
            current_node->children.push_back(loop);
        }
        loop->children.push_back(node);
    });
    visit_one_to_one({vpiCondition}, obj_h, [&](AST::AstNode *node) { loop->children.push_back(node); });
    visit_one_to_many({vpiForIncStmt}, obj_h, [&](AST::AstNode *node) {
        if (node->type == AST::AST_ASSIGN_LE)
            node->type = AST::AST_ASSIGN_EQ;
        loop->children.push_back(node);
    });
    visit_one_to_one({vpiStmt}, obj_h, [&](AST::AstNode *node) {
        if (node->type != AST::AST_BLOCK) {
            auto *statements = make_ast_node(AST::AST_BLOCK);
            statements->str = current_node->str; // Needed in simplify step
            statements->children.push_back(node);
            loop->children.push_back(statements);
        } else {
            if (node->str == "") {
                node->str = loop->str;
            }
            loop->children.push_back(node);
        }
    });
}

void UhdmAst::process_gen_scope()
{
    current_node = make_ast_node(AST::AST_GENBLOCK);
    visit_one_to_many({vpiTypedef}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            move_type_to_new_typedef(current_node, node);
        }
    });

    visit_one_to_many(
      {vpiParamAssign, vpiParameter, vpiNet, vpiArrayNet, vpiVariables, vpiContAssign, vpiProcess, vpiModule, vpiGenScopeArray, vpiTaskFunc}, obj_h,
      [&](AST::AstNode *node) {
          if (node) {
              if ((node->type == AST::AST_PARAMETER || node->type == AST::AST_LOCALPARAM) && node->children.empty()) {
                  delete node; // skip parameters without any children
              } else {
                  current_node->children.push_back(node);
              }
          }
      });
}

void UhdmAst::process_case()
{
    current_node = make_ast_node(AST::AST_CASE);
    visit_one_to_one({vpiCondition}, obj_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
    visit_one_to_many({vpiCaseItem}, obj_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
}

void UhdmAst::process_case_item()
{
    current_node = make_ast_node(AST::AST_COND);
    vpiHandle itr = vpi_iterate(vpiExpr, obj_h);
    while (vpiHandle expr_h = vpi_scan(itr)) {
        // case ... inside statement, the operation is stored in UHDM inside case items
        // Retrieve just the InsideOp arguments here, we don't add any special handling
        // TODO: handle inside range (list operations) properly here
        if (vpi_get(vpiType, expr_h) == vpiOperation && vpi_get(vpiOpType, expr_h) == vpiInsideOp) {
            visit_one_to_many({vpiOperand}, expr_h, [&](AST::AstNode *node) {
                if (node) {
                    current_node->children.push_back(node);
                }
            });
        } else {
            UhdmAst uhdm_ast(this, shared, indent + "  ");
            auto *node = uhdm_ast.process_object(expr_h);
            if (node) {
                current_node->children.push_back(node);
            }
        }
        // FIXME: If we release the handle here, visiting vpiStmt fails for some reason
        // vpi_release_handle(expr_h);
    }
    vpi_release_handle(itr);
    if (current_node->children.empty()) {
        current_node->children.push_back(new AST::AstNode(AST::AST_DEFAULT));
    }
    visit_one_to_one({vpiStmt}, obj_h, [&](AST::AstNode *node) {
        if (node->type != AST::AST_BLOCK) {
            auto block_node = new AST::AstNode(AST::AST_BLOCK);
            block_node->children.push_back(node);
            node = block_node;
        }
        current_node->children.push_back(node);
    });
}

void UhdmAst::process_range(const UHDM::BaseClass *object)
{
    current_node = make_ast_node(AST::AST_RANGE);
    visit_one_to_one({vpiLeftRange, vpiRightRange}, obj_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
    if (current_node->children.size() > 0) {
        if (current_node->children[0]->str == "unsized") {
            log_error("%s:%d: Currently not supported object of type 'unsized range'\n", object->VpiFile().c_str(), object->VpiLineNo());
        }
    }
    if (current_node->children.size() > 1) {
        if (current_node->children[1]->str == "unsized") {
            log_error("%s:%d: Currently not supported object of type 'unsized range'\n", object->VpiFile().c_str(), object->VpiLineNo());
        }
    }
}

void UhdmAst::process_return()
{
    current_node = make_ast_node(AST::AST_ASSIGN_EQ);
    auto func_node = find_ancestor({AST::AST_FUNCTION, AST::AST_TASK});
    if (!func_node->children.empty()) {
        auto lhs = new AST::AstNode(AST::AST_IDENTIFIER);
        lhs->str = func_node->children[0]->str;
        current_node->children.push_back(lhs);
    }
    visit_one_to_one({vpiCondition}, obj_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
}

void UhdmAst::process_function()
{
    current_node = make_ast_node(vpi_get(vpiType, obj_h) == vpiFunction ? AST::AST_FUNCTION : AST::AST_TASK);
    visit_one_to_one({vpiReturn}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            auto net_type = vpi_get(vpiNetType, obj_h);
            node->is_reg = net_type == vpiReg;
            node->str = current_node->str;
            current_node->children.push_back(node);
        }
    });
    visit_one_to_many({vpiParameter, vpiParamAssign}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            add_or_replace_child(current_node, node);
        }
    });
    visit_one_to_many({vpiIODecl}, obj_h, [&](AST::AstNode *node) {
        node->type = AST::AST_WIRE;
        node->port_id = shared.next_port_id();
        current_node->children.push_back(node);
    });
    visit_one_to_many({vpiVariables}, obj_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
    visit_one_to_one({vpiStmt}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            // Fix for assignments on declaration, e.g.:
            // logic [63:0] key_out = key_in;
            // key_out is already declared as vpiVariables, but it is also declared inside vpiStmt
            const std::unordered_set<AST::AstNodeType> assign_types = {AST::AST_ASSIGN, AST::AST_ASSIGN_EQ, AST::AST_ASSIGN_LE};
            for (auto c : node->children) {
                if (assign_types.find(c->type) != assign_types.end() && c->children[0]->type == AST::AST_WIRE) {
                    c->children[0]->type = AST::AST_IDENTIFIER;
                    c->children[0]->attributes.erase(UhdmAst::packed_ranges());
                    c->children[0]->attributes.erase(UhdmAst::unpacked_ranges());
                }
            }
            current_node->children.push_back(node);
        }
    });
}

void UhdmAst::process_hier_path()
{
    current_node = make_ast_node(AST::AST_IDENTIFIER);
    current_node->str = "\\";
    AST::AstNode *top_node = nullptr;
    visit_one_to_many({vpiActual}, obj_h, [&](AST::AstNode *node) {
        if (node->str.find('[') != std::string::npos)
            node->str = node->str.substr(0, node->str.find('['));
        // for first node, just set correct string and move any children
        if (!top_node) {
            current_node->str += node->str.substr(1);
            current_node->children = std::move(node->children);
            top_node = current_node;
            delete node;
        } else {
            if (node->str.empty()) {
                log_assert(!node->children.empty());
                top_node->children.push_back(node->children[0]);
            } else {
                node->type = static_cast<AST::AstNodeType>(AST::AST_DOT);
                top_node->children.push_back(node);
                top_node = node;
            }
        }
    });
}

void UhdmAst::process_gen_scope_array()
{
    current_node = make_ast_node(AST::AST_GENBLOCK);
    visit_one_to_many({vpiGenScope}, obj_h, [&](AST::AstNode *genscope_node) {
        for (auto *child : genscope_node->children) {
            if (child->type == AST::AST_PARAMETER || child->type == AST::AST_LOCALPARAM) {
                auto param_str = child->str.substr(1);
                auto array_str = "[" + param_str + "]";
                visitEachDescendant(genscope_node, [&](AST::AstNode *node) {
                    auto pos = node->str.find(array_str);
                    if (pos != std::string::npos) {
                        node->type = AST::AST_PREFIX;
                        auto *param = new AST::AstNode(AST::AST_IDENTIFIER);
                        param->str = child->str;
                        node->children.push_back(param);
                        auto bracket = node->str.rfind(']');
                        if (bracket + 2 <= node->str.size()) {
                            auto *field = new AST::AstNode(AST::AST_IDENTIFIER);
                            field->str = "\\" + node->str.substr(bracket + 2);
                            node->children.push_back(field);
                        }
                        node->str = node->str.substr(0, node->str.find('['));
                    }
                });
            }
        }
        current_node->children.insert(current_node->children.end(), genscope_node->children.begin(), genscope_node->children.end());
        genscope_node->children.clear();
        delete genscope_node;
    });
}

void UhdmAst::process_tagged_pattern()
{
    auto assign_node = find_ancestor({AST::AST_ASSIGN, AST::AST_ASSIGN_EQ, AST::AST_ASSIGN_LE});
    auto assign_type = AST::AST_ASSIGN;
    AST::AstNode *lhs_node = nullptr;
    if (assign_node) {
        assign_type = assign_node->type;
        lhs_node = assign_node->children[0];
    } else {
        lhs_node = new AST::AstNode(AST::AST_IDENTIFIER);
        auto ancestor = find_ancestor({AST::AST_WIRE, AST::AST_MEMORY, AST::AST_PARAMETER, AST::AST_LOCALPARAM});
        if (!ancestor) {
            log_error("Couldn't find ancestor for tagged pattern!\n");
        }
        lhs_node->str = ancestor->str;
    }
    current_node = new AST::AstNode(assign_type);
    current_node->children.push_back(lhs_node->clone());
    auto typespec_h = vpi_handle(vpiTypespec, obj_h);
    if (vpi_get(vpiType, typespec_h) == vpiStringTypespec) {
        std::string field_name = vpi_get_str(vpiName, typespec_h);
        if (field_name != "default") { // TODO: better support of the default keyword
            auto field = new AST::AstNode(static_cast<AST::AstNodeType>(AST::AST_DOT));
            field->str = field_name;
            current_node->children[0]->children.push_back(field);
        }
    } else if (vpi_get(vpiType, typespec_h) == vpiIntegerTypespec) {
        s_vpi_value val;
        vpi_get_value(typespec_h, &val);
        auto range = new AST::AstNode(AST::AST_RANGE);
        auto index = AST::AstNode::mkconst_int(val.value.integer, false);
        range->children.push_back(index);
        current_node->children[0]->children.push_back(range);
    }
    vpi_release_handle(typespec_h);
    visit_one_to_one({vpiPattern}, obj_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
}

void UhdmAst::process_logic_var()
{
    current_node = make_ast_node(AST::AST_WIRE);
    current_node->is_logic = true;
    std::vector<AST::AstNode *> packed_ranges;   // comes before wire name
    std::vector<AST::AstNode *> unpacked_ranges; // comes after wire name
    // TODO: add const attribute, but it seems it is little more
    // then just setting boolean value
    // current_node->is_const = vpi_get(vpiConstantVariable, obj_h);
    visit_one_to_one({vpiTypespec}, obj_h, [&](AST::AstNode *node) {
        if (node->str.empty()) {
            // anonymous typespec, move the children to variable
            current_node->type = node->type;
            current_node->children = std::move(node->children);
        } else {
            auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
            wiretype_node->str = node->str;
            current_node->children.push_back(wiretype_node);
            current_node->is_custom_type = true;
        }
        delete node;
    });
    // TODO: Handling below seems similar to other typespec accesses for range. Candidate for extraction to a function.
    if (auto typespec_h = vpi_handle(vpiTypespec, obj_h)) {
        visit_one_to_many({vpiRange}, typespec_h, [&](AST::AstNode *node) { packed_ranges.push_back(node); });
        vpi_release_handle(typespec_h);
    } else {
        visit_one_to_many({vpiRange}, obj_h, [&](AST::AstNode *node) { packed_ranges.push_back(node); });
    }
    visit_default_expr(obj_h);
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges);
}

void UhdmAst::process_sys_func_call()
{
    current_node = make_ast_node(AST::AST_FCALL);

    // skip unsupported simulation functions
    std::string to_skip[] = {
      "\\$value$plusargs", "\\$test$plusargs", "\\$displayb", "\\$displayh",  "\\$displayo",  "\\$strobeb",  "\\$strobeh",       "\\$strobeo",
      "\\$writeb",         "\\$writeh",        "\\$writeo",   "\\$dumplimit", "\\$dumpflush", "\\$fdisplay", "\\$fdisplayb",     "\\$fdisplayh",
      "\\$fdisplayo",      "\\$fmonitor",      "\\$fstrobe",  "\\$fstrobeb",  "\\$fstrobeh",  "\\$fstrobeo", "\\$fwrite",        "\\$fwriteb",
      "\\$fwriteh",        "\\$fwriteo",       "\\$ungetc",   "\\$fgetc",     "\\$fgets",     "\\$ftell",    "\\$printtimescale"};

    if (std::find(std::begin(to_skip), std::end(to_skip), current_node->str) != std::end(to_skip)) {
        log_warning("System function %s was skipped\n", current_node->str.substr(1).c_str());
        delete current_node;
        current_node = nullptr;
        return;
    }

    std::string task_calls[] = {"\\$display", "\\$monitor", "\\$write", "\\$time", "\\$readmemh", "\\$readmemb", "\\$finish", "\\$stop"};

    if (current_node->str == "\\$signed") {
        current_node->type = AST::AST_TO_SIGNED;
    } else if (current_node->str == "\\$unsigned") {
        current_node->type = AST::AST_TO_UNSIGNED;
    } else if (std::find(std::begin(task_calls), std::end(task_calls), current_node->str) != std::end(task_calls)) {
        current_node->type = AST::AST_TCALL;
    }

    visit_one_to_many({vpiArgument}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            current_node->children.push_back(node);
        }
    });

    if (current_node->str == "\\$display" || current_node->str == "\\$write") {
        // According to standard, %h and %x mean the same, but %h is currently unsupported by mainline yosys
        std::string replaced_string = std::regex_replace(current_node->children[0]->str, std::regex("%[h|H]"), "%x");
        delete current_node->children[0];
        current_node->children[0] = AST::AstNode::mkconst_str(replaced_string);
    }

    std::string remove_backslash[] = {"\\$display", "\\$strobe",   "\\$write",    "\\$monitor", "\\$time",    "\\$finish",
                                      "\\$stop",    "\\$dumpfile", "\\$dumpvars", "\\$dumpon",  "\\$dumpoff", "\\$dumpall"};

    if (std::find(std::begin(remove_backslash), std::end(remove_backslash), current_node->str) != std::end(remove_backslash))
        current_node->str = current_node->str.substr(1);
}

void UhdmAst::process_func_call()
{
    current_node = make_ast_node(AST::AST_FCALL);
    visit_one_to_many({vpiArgument}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            if (node->type == AST::AST_PARAMETER || node->type == AST::AST_LOCALPARAM) {
                node->type = AST::AST_IDENTIFIER;
                node->children.clear();
            }
            current_node->children.push_back(node);
        }
    });
}

void UhdmAst::process_immediate_assert()
{
    current_node = make_ast_node(AST::AST_ASSERT);
    visit_one_to_one({vpiExpr}, obj_h, [&](AST::AstNode *n) {
        if (n) {
            current_node->children.push_back(n);
        }
    });
}

void UhdmAst::process_nonsynthesizable(const UHDM::BaseClass *object)
{
    log_warning("%s:%d: Non-synthesizable object of type '%s'\n", object->VpiFile().c_str(), object->VpiLineNo(), UHDM::VpiTypeName(obj_h).c_str());
    current_node = make_ast_node(AST::AST_BLOCK);
    visit_one_to_one({vpiStmt}, obj_h, [&](AST::AstNode *node) {
        if (node)
            current_node->children.push_back(node);
    });
}

void UhdmAst::process_logic_typespec()
{
    current_node = make_ast_node(AST::AST_WIRE);
    current_node->is_logic = true;
    std::vector<AST::AstNode *> packed_ranges;   // comes before wire name
    std::vector<AST::AstNode *> unpacked_ranges; // comes after wire name
    if (!current_node->str.empty() && current_node->str.find("::") == std::string::npos) {
        std::string package_name = "";
        if (vpiHandle instance_h = vpi_handle(vpiInstance, obj_h)) {
            if (vpi_get(vpiType, instance_h) == vpiPackage) {
                package_name = get_object_name(instance_h, {vpiDefName});
                current_node->str = package_name + "::" + current_node->str.substr(1);
            }
            vpi_release_handle(instance_h);
        }
    }
    visit_one_to_many({vpiRange}, obj_h, [&](AST::AstNode *node) { packed_ranges.push_back(node); });
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges);
}

void UhdmAst::process_int_typespec()
{
    std::vector<AST::AstNode *> packed_ranges;   // comes before wire name
    std::vector<AST::AstNode *> unpacked_ranges; // comes after wire name
    current_node = make_ast_node(AST::AST_WIRE);
    packed_ranges.push_back(make_range(31, 0));
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges);
    current_node->is_signed = true;
}

void UhdmAst::process_shortint_typespec()
{
    std::vector<AST::AstNode *> packed_ranges;   // comes before wire name
    std::vector<AST::AstNode *> unpacked_ranges; // comes after wire name
    current_node = make_ast_node(AST::AST_WIRE);
    packed_ranges.push_back(make_range(15, 0));
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges);
    current_node->is_signed = true;
}

void UhdmAst::process_byte_typespec()
{
    std::vector<AST::AstNode *> packed_ranges;   // comes before wire name
    std::vector<AST::AstNode *> unpacked_ranges; // comes after wire name
    current_node = make_ast_node(AST::AST_WIRE);
    packed_ranges.push_back(make_range(7, 0));
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges);
    current_node->is_signed = true;
}

void UhdmAst::process_time_typespec()
{
    std::vector<AST::AstNode *> packed_ranges;   // comes before wire name
    std::vector<AST::AstNode *> unpacked_ranges; // comes after wire name
    current_node = make_ast_node(AST::AST_WIRE);
    packed_ranges.push_back(make_range(63, 0));
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges);
    current_node->is_signed = false;
}

void UhdmAst::process_string_var()
{
    current_node = make_ast_node(AST::AST_WIRE);
    current_node->is_string = true;
    // FIXME:
    // this is only basic support for strings,
    // currently yosys doesn't support dynamic resize of wire
    // based on string size
    // here we try to get size of string based on provided const string
    // if it is not available, we are setting size to explicite 64 bits
    visit_one_to_one({vpiExpr}, obj_h, [&](AST::AstNode *expr_node) {
        if (expr_node->type == AST::AST_CONSTANT) {
            auto left_const = AST::AstNode::mkconst_int(expr_node->range_left, true);
            auto right_const = AST::AstNode::mkconst_int(expr_node->range_right, true);
            auto range = make_ast_node(AST::AST_RANGE, {left_const, right_const});
            current_node->children.push_back(range);
        }
    });
    if (current_node->children.empty()) {
        auto left_const = AST::AstNode::mkconst_int(64, true);
        auto right_const = AST::AstNode::mkconst_int(0, true);
        auto range = make_ast_node(AST::AST_RANGE, {left_const, right_const});
        current_node->children.push_back(range);
    }
    visit_default_expr(obj_h);
}

void UhdmAst::process_string_typespec()
{
    current_node = make_ast_node(AST::AST_WIRE);
    current_node->is_string = true;
    // FIXME:
    // this is only basic support for strings,
    // currently yosys doesn't support dynamic resize of wire
    // based on string size
    // here, we are setting size to explicite 64 bits
    auto left_const = AST::AstNode::mkconst_int(64, true);
    auto right_const = AST::AstNode::mkconst_int(0, true);
    auto range = make_ast_node(AST::AST_RANGE, {left_const, right_const});
    current_node->children.push_back(range);
}

void UhdmAst::process_bit_typespec()
{
    current_node = make_ast_node(AST::AST_WIRE);
    visit_range(obj_h, [&](AST::AstNode *node) {
        if (node) {
            current_node->children.push_back(node);
        }
    });
}

void UhdmAst::process_repeat()
{
    current_node = make_ast_node(AST::AST_REPEAT);
    visit_one_to_one({vpiCondition}, obj_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
    visit_one_to_one({vpiStmt}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            AST::AstNode *block = nullptr;
            if (node->type != AST::AST_BLOCK) {
                block = new AST::AstNode(AST::AST_BLOCK, node);
            } else {
                block = node;
            }
            current_node->children.push_back(block);
        }
    });
}

void UhdmAst::process_var_select()
{
    current_node = make_ast_node(AST::AST_IDENTIFIER);
    visit_one_to_many({vpiIndex}, obj_h, [&](AST::AstNode *node) {
        if (node->str == current_node->str) {
            for (auto child : node->children) {
                current_node->children.push_back(child);
            }
            node->children.clear();
            delete node;
        } else {
            auto range_node = new AST::AstNode(AST::AST_RANGE);
            range_node->filename = current_node->filename;
            range_node->location = current_node->location;
            range_node->children.push_back(node);
            current_node->children.push_back(range_node);
        }
    });
}

void UhdmAst::process_port()
{
    current_node = make_ast_node(AST::AST_WIRE);
    current_node->port_id = shared.next_port_id();
    vpiHandle lowConn_h = vpi_handle(vpiLowConn, obj_h);
    std::vector<AST::AstNode *> packed_ranges;   // comes before wire name
    std::vector<AST::AstNode *> unpacked_ranges; // comes after wire name
    if (lowConn_h) {
        vpiHandle actual_h = vpi_handle(vpiActual, lowConn_h);
        auto actual_type = vpi_get(vpiType, actual_h);
        switch (actual_type) {
        case vpiModport: {
            vpiHandle iface_h = vpi_handle(vpiInterface, actual_h);
            if (iface_h) {
                std::string cellName, ifaceName;
                if (auto s = vpi_get_str(vpiName, actual_h)) {
                    cellName = s;
                    sanitize_symbol_name(cellName);
                }
                if (auto s = vpi_get_str(vpiDefName, iface_h)) {
                    ifaceName = s;
                    sanitize_symbol_name(ifaceName);
                }
                current_node->type = AST::AST_INTERFACEPORT;
                auto typeNode = new AST::AstNode(AST::AST_INTERFACEPORTTYPE);
                // Skip '\' in cellName
                typeNode->str = ifaceName + '.' + cellName.substr(1, cellName.length());
                current_node->children.push_back(typeNode);
                shared.report.mark_handled(actual_h);
                shared.report.mark_handled(iface_h);
                vpi_release_handle(iface_h);
            }
            break;
        }
        case vpiInterface: {
            auto typeNode = new AST::AstNode(AST::AST_INTERFACEPORTTYPE);
            if (auto s = vpi_get_str(vpiDefName, actual_h)) {
                typeNode->str = s;
                sanitize_symbol_name(typeNode->str);
            }
            current_node->type = AST::AST_INTERFACEPORT;
            current_node->children.push_back(typeNode);
            shared.report.mark_handled(actual_h);
            break;
        }
        case vpiLogicVar:
        case vpiLogicNet: {
            current_node->is_logic = true;
            current_node->is_signed = vpi_get(vpiSigned, actual_h);
            visit_one_to_many({vpiRange}, actual_h, [&](AST::AstNode *node) { packed_ranges.push_back(node); });
            shared.report.mark_handled(actual_h);
            break;
        }
        case vpiPackedArrayVar:
            visit_one_to_many({vpiElement}, actual_h, [&](AST::AstNode *node) {
                if (node && GetSize(node->children) == 1) {
                    current_node->children.push_back(node->children[0]);
                    if (node->children[0]->type == AST::AST_WIRETYPE) {
                        current_node->is_custom_type = true;
                    }
                }
            });
            visit_one_to_many({vpiRange}, actual_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
            shared.report.mark_handled(actual_h);
            break;
        case vpiPackedArrayNet:
            visit_one_to_many({vpiRange}, actual_h, [&](AST::AstNode *node) { packed_ranges.push_back(node); });
            shared.report.mark_handled(actual_h);
            break;
        case vpiArrayVar:
            visit_one_to_many({vpiRange}, actual_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
            shared.report.mark_handled(actual_h);
            break;
        case vpiEnumNet:
        case vpiStructNet:
        case vpiArrayNet:
        case vpiStructVar:
        case vpiUnionVar:
        case vpiEnumVar:
        case vpiShortIntVar:
        case vpiIntVar:
        case vpiIntegerVar:
            break;
        default: {
            const uhdm_handle *const handle = (const uhdm_handle *)actual_h;
            const UHDM::BaseClass *const object = (const UHDM::BaseClass *)handle->object;
            report_error("%s:%d: Encountered unhandled type in process_port: %s\n", object->VpiFile().c_str(), object->VpiLineNo(),
                         UHDM::VpiTypeName(actual_h).c_str());
            break;
        }
        }
        shared.report.mark_handled(lowConn_h);
        vpi_release_handle(actual_h);
        vpi_release_handle(lowConn_h);
    }
    visit_one_to_one({vpiTypedef}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            if (!current_node->children.empty() && current_node->children[0]->type != AST::AST_WIRETYPE) {
                if (!node->str.empty()) {
                    auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
                    wiretype_node->str = node->str;
                    // wiretype needs to be 1st node (if port have also another range nodes)
                    current_node->children.insert(current_node->children.begin(), wiretype_node);
                    current_node->is_custom_type = true;
                } else {
                    // anonymous typedef, just move children
                    current_node->children = std::move(node->children);
                }
            }
            delete node;
        }
    });
    if (const int n = vpi_get(vpiDirection, obj_h)) {
        if (n == vpiInput) {
            current_node->is_input = true;
        } else if (n == vpiOutput) {
            current_node->is_output = true;
        } else if (n == vpiInout) {
            current_node->is_input = true;
            current_node->is_output = true;
        }
    }
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges);
}

void UhdmAst::process_net()
{
    current_node = make_ast_node(AST::AST_WIRE);
    std::vector<AST::AstNode *> packed_ranges;   // comes before wire name
    std::vector<AST::AstNode *> unpacked_ranges; // comes after wire name
    auto net_type = vpi_get(vpiNetType, obj_h);
    current_node->is_reg = net_type == vpiReg;
    current_node->is_output = net_type == vpiOutput;
    current_node->is_logic = !current_node->is_reg;
    current_node->is_signed = vpi_get(vpiSigned, obj_h);
    visit_one_to_one({vpiTypespec}, obj_h, [&](AST::AstNode *node) {
        if (node && !node->str.empty()) {
            auto wiretype_node = new AST::AstNode(AST::AST_WIRETYPE);
            wiretype_node->str = node->str;
            // wiretype needs to be 1st node
            current_node->children.insert(current_node->children.begin(), wiretype_node);
            current_node->is_custom_type = true;
        }
    });
    if (vpiHandle typespec_h = vpi_handle(vpiTypespec, obj_h)) {
        visit_one_to_many({vpiRange}, typespec_h, [&](AST::AstNode *node) { packed_ranges.push_back(node); });
        vpi_release_handle(typespec_h);
    }
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges);
}

void UhdmAst::process_parameter()
{
    auto type = vpi_get(vpiLocalParam, obj_h) == 1 ? AST::AST_LOCALPARAM : AST::AST_PARAMETER;
    current_node = make_ast_node(type, {}, true);
    std::vector<AST::AstNode *> packed_ranges;   // comes before wire name
    std::vector<AST::AstNode *> unpacked_ranges; // comes after wire name
    // currently unused, but save it for future use
    if (const char *imported = vpi_get_str(vpiImported, obj_h); imported != nullptr && strlen(imported) > 0) {
        current_node->attributes[UhdmAst::is_imported()] = AST::AstNode::mkconst_int(1, true);
    }
    visit_one_to_many({vpiRange}, obj_h, [&](AST::AstNode *node) { unpacked_ranges.push_back(node); });
    vpiHandle typespec_h = vpi_handle(vpiTypespec, obj_h);
    if (typespec_h) {
        int typespec_type = vpi_get(vpiType, typespec_h);
        switch (typespec_type) {
        case vpiBitTypespec:
        case vpiLogicTypespec: {
            current_node->is_logic = true;
            visit_one_to_many({vpiRange}, typespec_h, [&](AST::AstNode *node) { packed_ranges.push_back(node); });
            shared.report.mark_handled(typespec_h);
            break;
        }
        case vpiByteTypespec: {
            packed_ranges.push_back(make_range(7, 0));
            shared.report.mark_handled(typespec_h);
            break;
        }
        case vpiEnumTypespec:
        case vpiRealTypespec:
        case vpiStringTypespec: {
            shared.report.mark_handled(typespec_h);
            break;
        }
        case vpiIntTypespec:
        case vpiIntegerTypespec: {
            packed_ranges.push_back(make_range(31, 0));
            shared.report.mark_handled(typespec_h);
            break;
        }
        case vpiStructTypespec: {
            visit_one_to_one({vpiTypespec}, obj_h, [&](AST::AstNode *node) {
                if (node && !node->str.empty()) {
                    auto wiretype_node = make_ast_node(AST::AST_WIRETYPE);
                    wiretype_node->str = node->str;
                    current_node->children.push_back(wiretype_node);
                }
                current_node->is_custom_type = true;
                auto it = shared.param_types.find(current_node->str);
                if (it == shared.param_types.end())
                    shared.param_types.insert(std::make_pair(current_node->str, node));
            });
            break;
        }
        case vpiPackedArrayTypespec:
        case vpiArrayTypespec: {
            shared.report.mark_handled(typespec_h);
            visit_one_to_one({vpiElemTypespec}, typespec_h, [&](AST::AstNode *node) {
                if (!node->str.empty()) {
                    auto wiretype_node = make_ast_node(AST::AST_WIRETYPE);
                    wiretype_node->str = node->str;
                    current_node->children.push_back(wiretype_node);
                    current_node->is_custom_type = true;
                    auto it = shared.param_types.find(current_node->str);
                    if (it == shared.param_types.end())
                        shared.param_types.insert(std::make_pair(current_node->str, node));
                }
                if (node && node->attributes.count(UhdmAst::packed_ranges())) {
                    for (auto r : node->attributes[UhdmAst::packed_ranges()]->children) {
                        packed_ranges.push_back(r->clone());
                    }
                }
            });
            break;
        }
        default: {
            const uhdm_handle *const handle = (const uhdm_handle *)typespec_h;
            const UHDM::BaseClass *const object = (const UHDM::BaseClass *)handle->object;
            report_error("%s:%d: Encountered unhandled typespec in process_parameter: '%s' of type '%s'\n", object->VpiFile().c_str(),
                         object->VpiLineNo(), object->VpiName().c_str(), UHDM::VpiTypeName(typespec_h).c_str());
            break;
        }
        }
        vpi_release_handle(typespec_h);
    }
    AST::AstNode *constant_node = process_value(obj_h);
    if (constant_node) {
        constant_node->filename = current_node->filename;
        constant_node->location = current_node->location;
        current_node->children.push_back(constant_node);
    }
    add_multirange_wire(current_node, packed_ranges, unpacked_ranges);
}

void UhdmAst::process_byte_var()
{
    current_node = make_ast_node(AST::AST_WIRE);
    current_node->children.push_back(make_range(7, 0));
    current_node->is_signed = vpi_get(vpiSigned, obj_h);
}

void UhdmAst::process_long_int_var()
{
    current_node = make_ast_node(AST::AST_WIRE);
    current_node->children.push_back(make_range(63, 0));
    current_node->is_signed = vpi_get(vpiSigned, obj_h);
}

void UhdmAst::process_immediate_cover()
{
    current_node = make_ast_node(AST::AST_COVER);
    visit_one_to_one({vpiExpr}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            current_node->children.push_back(node);
        }
    });
}

void UhdmAst::process_immediate_assume()
{
    current_node = make_ast_node(AST::AST_ASSUME);
    visit_one_to_one({vpiExpr}, obj_h, [&](AST::AstNode *node) {
        if (node) {
            current_node->children.push_back(node);
        }
    });
}

void UhdmAst::process_while()
{
    current_node = make_ast_node(AST::AST_WHILE);
    visit_one_to_one({vpiCondition}, obj_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
    visit_one_to_one({vpiStmt}, obj_h, [&](AST::AstNode *node) {
        if (node->type != AST::AST_BLOCK) {
            auto *statements = make_ast_node(AST::AST_BLOCK);
            statements->str = current_node->str; // Needed in simplify step
            statements->children.push_back(node);
            current_node->children.push_back(statements);
        } else {
            if (node->str == "") {
                node->str = current_node->str;
                current_node->children.push_back(node);
            }
        }
    });
}

void UhdmAst::process_gate()
{
    current_node = make_ast_node(AST::AST_PRIMITIVE);
    switch (vpi_get(vpiPrimType, obj_h)) {
    case vpiAndPrim:
        current_node->str = "and";
        break;
    case vpiNandPrim:
        current_node->str = "nand";
        break;
    case vpiNorPrim:
        current_node->str = "nor";
        break;
    case vpiOrPrim:
        current_node->str = "or";
        break;
    case vpiXorPrim:
        current_node->str = "xor";
        break;
    case vpiXnorPrim:
        current_node->str = "xnor";
        break;
    case vpiBufPrim:
        current_node->str = "buf";
        break;
    case vpiNotPrim:
        current_node->str = "not";
        break;
    default:
        log_file_error(current_node->filename, current_node->location.first_line, "Encountered unhandled gate type: %s", current_node->str.c_str());
        break;
    }
    visit_one_to_many({vpiPrimTerm}, obj_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
}

void UhdmAst::process_primterm()
{
    current_node = make_ast_node(AST::AST_ARGUMENT);
    visit_one_to_one({vpiExpr}, obj_h, [&](AST::AstNode *node) { current_node->children.push_back(node); });
}

void UhdmAst::process_unsupported_stmt(const UHDM::BaseClass *object)
{
    log_error("%s:%d: Currently not supported object of type '%s'\n", object->VpiFile().c_str(), object->VpiLineNo(),
              UHDM::VpiTypeName(obj_h).c_str());
}

AST::AstNode *UhdmAst::process_object(vpiHandle obj_handle)
{
    obj_h = obj_handle;
    const unsigned object_type = vpi_get(vpiType, obj_h);
    const uhdm_handle *const handle = (const uhdm_handle *)obj_h;
    const UHDM::BaseClass *const object = (const UHDM::BaseClass *)handle->object;

    if (shared.debug_flag) {
        std::cout << indent << "Object '" << object->VpiName() << "' of type '" << UHDM::VpiTypeName(obj_h) << '\'' << std::endl;
    }

    switch (object_type) {
    case vpiDesign:
        process_design();
        break;
    case vpiParameter:
        process_parameter();
        break;
    case vpiPort:
        process_port();
        break;
    case vpiModule:
        process_module();
        break;
    case vpiStructTypespec:
        process_struct_typespec();
        break;
    case vpiUnionTypespec:
        process_union_typespec();
        break;
    case vpiPackedArrayTypespec:
        process_packed_array_typespec();
        break;
    case vpiArrayTypespec:
        process_array_typespec();
        break;
    case vpiTypespecMember:
        process_typespec_member();
        break;
    case vpiEnumTypespec:
        process_enum_typespec();
        break;
    case vpiEnumConst:
        process_enum_const();
        break;
    case vpiEnumVar:
    case vpiEnumNet:
    case vpiStructVar:
    case vpiStructNet:
    case vpiUnionVar:
        process_custom_var();
        break;
    case vpiShortIntVar:
    case vpiIntVar:
    case vpiIntegerVar:
        process_int_var();
        break;
    case vpiShortRealVar:
    case vpiRealVar:
        process_real_var();
        break;
    case vpiPackedArrayVar:
        process_packed_array_var();
        break;
    case vpiArrayVar:
        process_array_var();
        break;
    case vpiParamAssign:
        process_param_assign();
        break;
    case vpiContAssign:
        process_cont_assign();
        break;
    case vpiAssignStmt:
    case vpiAssignment:
        process_assignment();
        break;
    case vpiRefVar:
    case vpiRefObj:
        current_node = make_ast_node(AST::AST_IDENTIFIER);
        break;
    case vpiNet:
        process_net();
        break;
    case vpiArrayNet:
        process_array_net(object);
        break;
    case vpiPackedArrayNet:
        process_packed_array_net();
        break;
    case vpiPackage:
        process_package();
        break;
    case vpiInterface:
        process_interface();
        break;
    case vpiModport:
        process_modport();
        break;
    case vpiIODecl:
        process_io_decl();
        break;
    case vpiAlways:
        process_always();
        break;
    case vpiEventControl:
        process_event_control(object);
        break;
    case vpiInitial:
        process_initial();
        break;
    case vpiNamedBegin:
        process_begin(true);
        break;
    case vpiBegin:
        process_begin(false);
        // for unnamed block, reset block name
        current_node->str = "";
        break;
    case vpiCondition:
    case vpiOperation:
        process_operation(object);
        break;
    case vpiTaggedPattern:
        process_tagged_pattern();
        break;
    case vpiBitSelect:
        process_bit_select();
        break;
    case vpiPartSelect:
        process_part_select();
        break;
    case vpiIndexedPartSelect:
        process_indexed_part_select();
        break;
    case vpiVarSelect:
        process_var_select();
        break;
    case vpiIf:
    case vpiIfElse:
        process_if_else();
        break;
    case vpiFor:
        process_for();
        break;
    case vpiGenScopeArray:
        process_gen_scope_array();
        break;
    case vpiGenScope:
        process_gen_scope();
        break;
    case vpiCase:
        process_case();
        break;
    case vpiCaseItem:
        process_case_item();
        break;
    case vpiConstant:
        current_node = process_value(obj_h);
        break;
    case vpiRange:
        process_range(object);
        break;
    case vpiReturn:
        process_return();
        break;
    case vpiFunction:
    case vpiTask:
        process_function();
        break;
    case vpiBitVar:
    case vpiLogicVar:
        process_logic_var();
        break;
    case vpiSysFuncCall:
        process_sys_func_call();
        break;
    case vpiFuncCall:
        process_func_call();
        break;
    case vpiTaskCall:
        current_node = make_ast_node(AST::AST_TCALL);
        break;
    case vpiImmediateAssert:
        if (!shared.no_assert)
            process_immediate_assert();
        break;
    case vpiAssert:
        if (!shared.no_assert)
            process_unsupported_stmt(object);
        break;
    case vpiHierPath:
        process_hier_path();
        break;
    case UHDM::uhdmimport_typespec:
        break;
    case vpiDelayControl:
        process_nonsynthesizable(object);
        break;
    case vpiLogicTypespec:
        process_logic_typespec();
        break;
    case vpiIntTypespec:
    case vpiIntegerTypespec:
        process_int_typespec();
        break;
    case vpiShortIntTypespec:
        process_shortint_typespec();
        break;
    case vpiTimeTypespec:
        process_time_typespec();
        break;
    case vpiBitTypespec:
        process_bit_typespec();
        break;
    case vpiByteTypespec:
        process_byte_typespec();
        break;
    case vpiStringVar:
        process_string_var();
        break;
    case vpiStringTypespec:
        process_string_typespec();
        break;
    case vpiRepeat:
        process_repeat();
        break;
    case vpiByteVar:
        process_byte_var();
        break;
    case vpiLongIntVar:
        process_long_int_var();
        break;
    case vpiImmediateCover:
        process_immediate_cover();
        break;
    case vpiImmediateAssume:
        process_immediate_assume();
        break;
    case vpiAssume:
        process_unsupported_stmt(object);
        break;
    case vpiWhile:
        process_while();
        break;
    case vpiGate:
        process_gate();
        break;
    case vpiPrimTerm:
        process_primterm();
        break;
    case vpiClockingBlock:
        process_unsupported_stmt(object);
        break;
    case vpiProgram:
    default:
        report_error("%s:%d: Encountered unhandled object '%s' of type '%s'\n", object->VpiFile().c_str(), object->VpiLineNo(),
                     object->VpiName().c_str(), UHDM::VpiTypeName(obj_h).c_str());
        break;
    }

    // Check if we initialized the node in switch-case
    if (current_node) {
        if (current_node->type != AST::AST_NONE) {
            shared.report.mark_handled(object);
            return current_node;
        }
    }
    return nullptr;
}

AST::AstNode *UhdmAst::visit_designs(const std::vector<vpiHandle> &designs)
{
    current_node = new AST::AstNode(AST::AST_DESIGN);
    for (auto design : designs) {
        UhdmAst ast(this, shared, indent);
        auto *nodes = ast.process_object(design);
        // Flatten multiple designs into one
        for (auto child : nodes->children) {
            current_node->children.push_back(child);
        }
    }
    return current_node;
}

void UhdmAst::report_error(const char *format, ...) const
{
    va_list args;
    va_start(args, format);
    if (shared.stop_on_error) {
        logv_error(format, args);
    } else {
        logv_warning(format, args);
    }
}

YOSYS_NAMESPACE_END
