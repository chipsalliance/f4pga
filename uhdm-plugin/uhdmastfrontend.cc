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

#include "API/PythonAPI.h"
#include "ErrorReporting/Report.h"
#include "StringUtils.h"
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

unsigned int executeCompilation(
		int argc, const char** argv, bool diff_comp_mode, bool fileunit,
		SURELOG::ErrorContainer::Stats* overallStats = NULL) {
	bool success = true;
	bool noFatalErrors = true;
	unsigned int codedReturn = 0;
	SURELOG::SymbolTable* symbolTable = new SURELOG::SymbolTable();
	SURELOG::ErrorContainer* errors = new SURELOG::ErrorContainer(symbolTable);
	SURELOG::CommandLineParser* clp = new SURELOG::CommandLineParser(
			errors, symbolTable, diff_comp_mode, fileunit);
	success = clp->parseCommandLine(argc, argv);
	bool parseOnly = clp->parseOnly();
	errors->printMessages(clp->muteStdout());
	if (success && (!clp->help())) {
		// Load Python scripts in the interpreter
		if (clp->pythonListener() || clp->pythonEvalScriptPerFile() ||
				clp->pythonEvalScript()) {
			SURELOG::PythonAPI::loadScripts();

			if (!SURELOG::PythonAPI::isListenerLoaded()) {
				SURELOG::Location loc(0);
				SURELOG::Error err(
						SURELOG::ErrorDefinition::PY_NO_PYTHON_LISTENER_FOUND, loc);
				errors->addError(err);
			}
		}

		SURELOG::scompiler* compiler = SURELOG::start_compiler(clp);
		if (!compiler) codedReturn |= 1;
		SURELOG::shutdown_compiler(compiler);
	}
	SURELOG::ErrorContainer::Stats stats;
	if (!clp->help()) {
		stats = errors->getErrorStats();
		if (overallStats) (*overallStats) += stats;
		if (stats.nbFatal) codedReturn |= 1;
		if (stats.nbSyntax) codedReturn |= 2;
		// Only return non-zero for fatal and syntax errors
		// if (stats.nbError)
		//	codedReturn |= 4;
	}
	bool noFErrors = true;
	if (!clp->help()) noFErrors = errors->printStats(stats, clp->muteStdout());
	if (noFErrors == false) {
		noFatalErrors = false;
	}

	std::string ext_command = clp->getExeCommand();
	if (!ext_command.empty()) {
		std::string directory = symbolTable->getSymbol(clp->getFullCompileDir());
		std::string fileList = directory + "/file.lst";
		std::string command = ext_command + " " + fileList;
		int result = system(command.c_str());
		codedReturn |= result;
		std::cout << "Command result: " << result << std::endl;
	}
	clp->logFooter();
	if (diff_comp_mode && fileunit) {
		SURELOG::Report* report = new SURELOG::Report();
		std::pair<bool, bool> results =
				report->makeDiffCompUnitReport(clp, symbolTable);
		success = results.first;
		noFatalErrors = results.second;
		delete report;
	}
	clp->cleanCache();	// only if -nocache
	delete clp;
	delete symbolTable;
	delete errors;
	if ((!noFatalErrors) || (!success)) codedReturn |= 1;
	if (parseOnly)
		return 0;
	else
		return codedReturn;
}

enum COMP_MODE {
	NORMAL,
	DIFF,
	BATCH,
};

int batchCompilation(const char* argv0, std::string batchFile, bool nostdout) {
	char path[10000];
	int returnCode = 0;
	SURELOG::ErrorContainer::Stats overallStats;
	char* p = getcwd(path, 9999);
	if (!p) returnCode |= 1;
	std::ifstream stream;
	stream.open(batchFile);
	if (!stream.good()) {
		returnCode |= 1;
		return returnCode;
	}
	std::string line;
	int count = 0;
	while (std::getline(stream, line)) {
		if (!nostdout)
			std::cout << "Processing: " << line << std::endl << std::flush;
		std::vector<std::string> args;
		SURELOG::StringUtils::tokenize(line, " ", args);
		int argc = args.size() + 1;
		char** argv = new char*[argc];
		argv[0] = new char[strlen(argv0) + 1];
		strcpy(argv[0], argv0);
		for (int i = 0; i < argc - 1; i++) {
			argv[i + 1] = new char[args[i].length() + 1];
			strcpy(argv[i + 1], args[i].c_str());
		}
		returnCode |= executeCompilation(argc, (const char**)argv, false, false, &overallStats);
		for (int i = 0; i < argc; i++) {
			delete[] argv[i];
		}
		delete[] argv;
		count++;
		int ret = chdir(path);
		if (ret < 0) {
			std::cout << "FATAL: Could not change directory to " << path << "\n" << std::endl;
			returnCode |= 1;
		}
	}
	if (!nostdout)
		std::cout << "Processed " << count << " tests." << std::endl << std::flush;
	SURELOG::SymbolTable* symbolTable = new SURELOG::SymbolTable();
	SURELOG::ErrorContainer* errors = new SURELOG::ErrorContainer(symbolTable);
	if (!nostdout) errors->printStats(overallStats);
	delete errors;
	delete symbolTable;
	stream.close();
	return returnCode;
}

int run_surelog(int argc, const char** argv) {
	SURELOG::Waiver::initWaivers();

	unsigned int codedReturn = 0;
	COMP_MODE mode = NORMAL;
	bool python_mode = true;
	bool nostdout = false;
	std::string batchFile;
	std::string diff_unit_opt = "-diffcompunit";
	std::string nopython_opt = "-nopython";
	std::string parseonly_opt = "-parseonly";
	std::string batch_opt = "-batch";
	std::string nostdout_opt = "-nostdout";
	for (int i = 1; i < argc; i++) {
		if (parseonly_opt == argv[i]) {
		} else if (diff_unit_opt == argv[i]) {
			mode = DIFF;
		} else if (nopython_opt == argv[i]) {
			python_mode = false;
		} else if (batch_opt == argv[i]) {
			batchFile = argv[i + 1];
			i++;
			mode = BATCH;
		} else if (nostdout_opt == argv[i]) {
			nostdout = true;
		}
	}

	if (python_mode) SURELOG::PythonAPI::init(argc, argv);

	switch (mode) {
		case DIFF: {
#if (defined(_MSC_VER) || defined(__MINGW32__) || defined(__CYGWIN__))
			// REVISIT: Windows doesn't have the concept of forks!
			// Implement it sequentially for now and optimize it if this
			// proves to be a bottleneck (preferably, implemented as a
			// cross platform solution).
			executeCompilation(argc, argv, true, false);
			codedReturn = executeCompilation(argc, argv, true, true);
#else
			pid_t pid = fork();
			if (pid == 0) {
				// child process
				executeCompilation(argc, argv, true, false);
			} else if (pid > 0) {
				// parent process
				codedReturn = executeCompilation(argc, argv, true, true);
			} else {
				// fork failed
				printf("fork() failed!\n");
				return 1;
			}
#endif
			break;
		}
		case NORMAL:
			codedReturn = executeCompilation(argc, argv, false, false);
			break;
		case BATCH:
			codedReturn = batchCompilation(argv[0], batchFile, nostdout);
			break;
	}

	if (python_mode) SURELOG::PythonAPI::shutdown();
	return codedReturn;
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
		if (!report_directory.empty()) {
			shared.report.write(report_directory);
		}
		for (auto design : restoredDesigns) vpi_release_handle(design);
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
} UhdmAstFrontend;

YOSYS_NAMESPACE_END
