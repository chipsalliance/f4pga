#include <fstream>
#include <unordered_set>
#include <sys/stat.h>
#include "BaseClass.h"
#include "frontends/ast/ast.h"
#include "uhdmastreport.h"

YOSYS_NAMESPACE_BEGIN

void UhdmAstReport::mark_handled(const UHDM::BaseClass* object) {
	handled_count_per_file.insert(std::make_pair(object->VpiFile(), 0));
	auto it = unhandled.find(object);
	if (it != unhandled.end()) {
		unhandled.erase(it);
		handled_count_per_file.at(object->VpiFile())++;
	}
}

void UhdmAstReport::mark_handled(const vpiHandle obj_h) {
	auto handle = reinterpret_cast<const uhdm_handle*>(obj_h);
	mark_handled(reinterpret_cast<const UHDM::BaseClass*>(handle->object));
}

static std::string replace_in_string(std::string str, const std::string& to_find, const std::string& to_replace_with) {
	size_t pos = str.find(to_find);
	while (pos != std::string::npos) {
		str.replace(pos, to_find.length(), to_replace_with);
		pos += to_replace_with.length();
		pos = str.find(to_find, pos);
	}
	return str;
}

void UhdmAstReport::write(const std::string& directory) {
	std::unordered_map<std::string, std::unordered_set<unsigned>> unhandled_per_file;
	for (auto object : unhandled) {
		if (object->VpiFile() != "" && object->VpiFile() != AST::current_filename) {
			unhandled_per_file.insert(std::make_pair(object->VpiFile(), std::unordered_set<unsigned>()));
			unhandled_per_file.at(object->VpiFile()).insert(object->VpiLineNo());
			handled_count_per_file.insert(std::make_pair(object->VpiFile(), 0));
		}
	}
	unsigned total_handled = 0;
	for (auto& hc : handled_count_per_file) {
		if (hc.first != "" && hc.first != AST::current_filename) {
			unhandled_per_file.insert(std::make_pair(hc.first, std::unordered_set<unsigned>()));
			total_handled += hc.second;
		}
	}
	float coverage = total_handled * 100.f / (total_handled + unhandled.size()); 
	mkdir(directory.c_str(), 0777);
	std::ofstream index_file(directory + "/index.html");
	index_file << "<!DOCTYPE html>\n<html>\n<head>\n<style>h3{margin:0;padding:10}</style>\n</head><body>" << std::endl;
	index_file << "<h2>Overall coverage: " << coverage << "%</h2>" << std::endl;
	for (auto& unhandled_in_file : unhandled_per_file) {
		// Calculate coverage in file
		unsigned handled_count = handled_count_per_file.at(unhandled_in_file.first);
		unsigned unhandled_count = unhandled_in_file.second.size();
		float coverage = handled_count * 100.f / (handled_count + unhandled_count);
		// Add to the index file
		std::string report_filename = replace_in_string(unhandled_in_file.first, "/", ".") + ".html";
		index_file << "<h3>Cov: " << coverage << "%<a href=\"" << report_filename << "\">" << unhandled_in_file.first << "</a></h3><br>" << std::endl;
		// Write the report file
		std::ofstream report_file(directory + '/' + report_filename);
		report_file << "<!DOCTYPE html>\n<html>\n<head>\n<style>\nbody{font-size:12px;}pre{display:inline}</style>\n</head><body>" << std::endl;
		report_file << "<h2>" << unhandled_in_file.first << " | Coverage: " << coverage << "%</h2>" << std::endl;
		std::ifstream source_file(unhandled_in_file.first); // Read the source code
		unsigned line_number = 1;
		std::string line;
		while (std::getline(source_file, line)) {
			if (unhandled_in_file.second.find(line_number) == unhandled_in_file.second.end()) {
				report_file << line_number << "<pre> " << line << "</pre><br>" << std::endl;
			} else {
				report_file << line_number << "<pre style=\"background-color: #FFB6C1;\"> " << line << "</pre><br>" << std::endl;
			}
			++line_number;
		}
		report_file << "</body>\n</html>" << std::endl;
	}
	index_file << "</body>\n</html>" << std::endl;
}

YOSYS_NAMESPACE_END
