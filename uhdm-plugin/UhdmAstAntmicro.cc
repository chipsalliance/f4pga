namespace RTLIL
{
namespace ID
{
IdString packed_ranges{"\\packed_ranges"};
IdString unpacked_ranges{"\\unpacked_ranges"};
} // namespace ID
} // namespace RTLIL
#define mkconst_real(x) AST::AstNode::mkconst_real(x)

void UhdmAst::process_packed_array_typespec()
{
    current_node = make_ast_node(AST::AST_WIRE);
    visit_one_to_one({vpiElemTypespec}, obj_h, [&](AST::AstNode *node) {
        if (node && node->type == AST::AST_STRUCT) {
            auto str = current_node->str;
            node->cloneInto(current_node);
            current_node->str = str;
            delete node;
        } else if (node) {
            current_node->str = node->str;
            delete node;
        }
    });
    visit_range(obj_h, [&](AST::AstNode *node) {
        if (node) {
            node->is_packed = true;
            current_node->children.push_back(node);
        }
    });
}
