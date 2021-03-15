#ifndef _UHDM_AST_REPORT_H_
#define _UHDM_AST_REPORT_H_ 1

#include <map>
#include <string>
#include <unordered_map>
#include "kernel/yosys.h"
#undef cover
#include "headers/uhdm.h"

YOSYS_NAMESPACE_BEGIN

class UhdmAstReport {
	private:
		// Maps a filename to the number of objects being handled by the frontend
		std::unordered_map<std::string, unsigned> handled_count_per_file;

	public:
		// Objects not being handled by the frontend
		std::set<const UHDM::BaseClass*> unhandled;

		// Marks the specified object as being handled by the frontend
		void mark_handled(const UHDM::BaseClass* object);

		// Marks the object referenced by the specified handle as being handled by the frontend
		void mark_handled(vpiHandle obj_h);

		// Write the coverage report to the specified path
		void write(const std::string& directory);
};

YOSYS_NAMESPACE_END

#endif
