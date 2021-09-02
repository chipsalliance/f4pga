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

#if defined(_MSC_VER)
#include <direct.h>
#include <process.h>
#else
#include <sys/param.h>
#include <unistd.h>
#endif

#include "ErrorReporting/Report.h"
#include "surelog.h"

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

std::vector<vpiHandle> executeCompilation(SURELOG::SymbolTable* symbolTable,
		SURELOG::ErrorContainer* errors, SURELOG::CommandLineParser* clp,
		SURELOG::scompiler* compiler) {
	bool success = true;
	bool noFatalErrors = true;
	unsigned int codedReturn = 0;
	clp->setWriteUhdm(false);
	errors->printMessages(clp->muteStdout());
	std::vector<vpiHandle> the_design;
	if (success && (!clp->help())) {
		compiler = SURELOG::start_compiler(clp);
		if (!compiler) codedReturn |= 1;
		the_design.push_back(SURELOG::get_uhdm_design(compiler));
	}
	SURELOG::ErrorContainer::Stats stats;
	if (!clp->help()) {
		stats = errors->getErrorStats();
		if (stats.nbFatal) codedReturn |= 1;
		if (stats.nbSyntax) codedReturn |= 2;
	}
	bool noFErrors = true;
	if (!clp->help()) noFErrors = errors->printStats(stats, clp->muteStdout());
	if (noFErrors == false) {
		noFatalErrors = false;
	}
	if ((!noFatalErrors) || (!success)) codedReturn |= 1;
	return the_design;
}

struct UhdmSurelogAstFrontend : public Frontend {
	UhdmSurelogAstFrontend() : Frontend("verilog_with_uhdm", "generate/read UHDM file") { }
	void help()
	{
		//   |---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|---v---|
		log("\n");
		log("    read_verilog_with_uhdm [options] [filenames]\n");
		log("\n");
		log("Generate or load design from a UHDM file into the current design\n");
		log("\n");
		log("    -process\n");
		log("        loads design from given UHDM file\n");
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
		log_header(design, "Executing Verilog with UHDM frontend.\n");

		UhdmAstShared shared;
		UhdmAst uhdm_ast(shared);
		bool defer = false;

		std::string report_directory;
		auto it = args.begin();
		while (it != args.end()) {
			if (*it == "-debug") {
				shared.debug_flag = true;
				it = args.erase(it);
			} else if (*it == "-report" && (it = args.erase(it)) < args.end()) {
				report_directory = *it;
				shared.stop_on_error = false;
				it = args.erase(it);
			} else if (*it == "-noassert") {
				shared.no_assert = true;
				it = args.erase(it);
			} else if (*it == "-defer") {
				defer = true;
				it = args.erase(it);
			} else {
				++it;
			}
		}
		std::vector<const char*> cstrings;
		cstrings.reserve(args.size());
		for(size_t i = 0; i < args.size(); ++i)
			cstrings.push_back(const_cast<char*>(args[i].c_str()));

		SURELOG::SymbolTable* symbolTable = new SURELOG::SymbolTable();
		SURELOG::ErrorContainer* errors = new SURELOG::ErrorContainer(symbolTable);
		SURELOG::CommandLineParser* clp = new SURELOG::CommandLineParser(
				errors, symbolTable, false, false);
		clp->parseCommandLine(cstrings.size(), &cstrings[0]);
		SURELOG::scompiler* compiler = nullptr;
		const std::vector<vpiHandle> uhdm_design = executeCompilation(symbolTable, errors, clp, compiler);
		struct AST::AstNode *current_ast = uhdm_ast.visit_designs(uhdm_design);
		if (report_directory != "") {
			shared.report.write(report_directory);
		}
		bool dump_ast1 = shared.debug_flag;
		bool dump_ast2 = shared.debug_flag;
		bool dont_redefine = false;
		bool default_nettype_wire = true;
		AST::process(design, current_ast,
			dump_ast1, dump_ast2, false, false, false, false, false, false, false, false,
			false, false, false, false, false, false, dont_redefine, false, defer, default_nettype_wire
		);
		delete current_ast;
		SURELOG::shutdown_compiler(compiler);
		delete clp;
		delete symbolTable;
		delete errors;
	}
} UhdmSurelogAstFrontend;

YOSYS_NAMESPACE_END

