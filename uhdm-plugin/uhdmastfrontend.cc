/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
 *  Copyright (C) 2020 Antmicro

 *  Based on frontends/json/jsonparse.cc
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

#include "kernel/yosys.h"
#include "frontends/ast/ast.h"
#include "UhdmAst.h"

namespace UHDM {
	extern void visit_object (vpiHandle obj_h, int indent, const char *relation, std::set<const BaseClass*>* visited, std::ostream& out, bool shallowVisit = false);
}


YOSYS_NAMESPACE_BEGIN

/* Stub for AST::process */
static void
set_line_num(int)
{
}

/* Stub for AST::process */
static int
get_line_num(void)
{
	return 1;
}

struct UhdmAstFrontend : public Frontend {
	UhdmAstFrontend() : Frontend("uhdm", "read UHDM file") { }
	void help()
	{
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("    read_uhdm [options] [filename]\n");
		log("\n");
		log("Load design from a UHDM file into the current design\n");
		log("\n");
		log("    -noassert\n");
		log("        ignore assert() statements");
		log("\n");
		log("    -debug\n");
		log("        print debug info to stdout");
		log("\n");
		log("    -report [directory]\n");
		log("        write a coverage report for the UHDM file\n");
		log("\n");
		log("    -defer\n");
		log("        only read the abstract syntax tree and defer actual compilation\n");
		log("        to a later 'hierarchy' command. Useful in cases where the default\n");
		log("        parameters of modules yield invalid or not synthesizable code.\n");
		log("\n");
	}
	void execute(std::istream *&f, std::string filename, std::vector<std::string> args, RTLIL::Design *design)
	{
		log_header(design, "Executing UHDM frontend.\n");

		UhdmAstShared shared;
		UhdmAst uhdm_ast(shared);
		bool defer = false;

		std::string report_directory;
		for (size_t i = 1; i < args.size(); i++) {
			if (args[i] == "-debug") {
				shared.debug_flag = true;
			} else if (args[i] == "-report" && ++i < args.size()) {
				report_directory = args[i];
				shared.stop_on_error = false;
			} else if (args[i] == "-noassert") {
				shared.no_assert = true;
			} else if (args[i] == "-defer") {
				defer = true;
			}
		}
		extra_args(f, filename, args, args.size() - 1);

		AST::current_filename = filename;
		AST::set_line_num = &set_line_num;
		AST::get_line_num = &get_line_num;
		struct AST::AstNode *current_ast;

		UHDM::Serializer serializer;

		std::vector<vpiHandle> restoredDesigns = serializer.Restore(filename);
		for (auto design : restoredDesigns) {
			std::stringstream strstr;
			UHDM::visit_object(design, 1, "", &shared.report.unhandled, shared.debug_flag ? std::cout : strstr);
		}
		current_ast = uhdm_ast.visit_designs(restoredDesigns);
		if (report_directory != "") {
			shared.report.write(report_directory);
		}
		cleanup(current_ast, shared);
		bool dump_ast1 = shared.debug_flag;
		bool dump_ast2 = shared.debug_flag;
		bool dont_redefine = false;
		bool default_nettype_wire = true;
		AST::process(design, current_ast,
			dump_ast1, dump_ast2, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, dont_redefine, false, defer, default_nettype_wire
		);
		delete current_ast;
	}

	void cleanup(AST::AstNode* ast, UhdmAstShared& shared) {
		std::unordered_set<AST::AstNode*> nodes_to_delete, visited;
		for (auto node : shared.visited) {
			nodes_to_delete.insert(node.second); // Put all visited nodes in a set
		}
		ast->visitEachDescendant([&nodes_to_delete, &visited](AST::AstNode* node) {
			nodes_to_delete.erase(node); // Prevent a node actually used in the AST from being deleted
			visited.insert(node); // Store it as visited
		});
		nodes_to_delete.erase(ast); // Prevent the root node from being deleted
		for (auto node : std::unordered_set<AST::AstNode*>(nodes_to_delete)) {
			node->visitEachDescendant([&nodes_to_delete](AST::AstNode* node) {
				nodes_to_delete.erase(node);
			});
			erase_repeating(node, visited); // Prevent deleting some nodes multiple times
		}
		for (auto node : nodes_to_delete) {
			delete node;
		}
		shared.visited.clear();
	}

	// Erases nodes that are in the 'visited' set from the AST
	void erase_repeating(AST::AstNode* node, std::unordered_set<AST::AstNode*>& visited) {
		visited.insert(node);
		node->children.erase(std::remove_if(node->children.begin(), node->children.end(),
											[&](AST::AstNode* x) {
												return visited.find(x) != visited.end();
											}), node->children.end());
		for (auto child : node->children) {
			erase_repeating(child, visited);
		}
	}

} UhdmAstFrontend;

YOSYS_NAMESPACE_END

