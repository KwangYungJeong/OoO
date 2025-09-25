#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <sstream>
#include "rat.hpp"

// Basic string trim functions
std::string& ltrim(std::string& s, const char* t = " \t\n\r\f\v") {
    s.erase(0, s.find_first_not_of(t));
    return s;
}
std::string& rtrim(std::string& s, const char* t = " \t\n\r\f\v") {
    s.erase(s.find_last_not_of(t) + 1);
    return s;
}
std::string& trim(std::string& s, const char* t = " \t\n\r\f\v") {
    return ltrim(rtrim(s, t), t);
}

int parse_register(const std::string& reg_str) {
    if (reg_str.empty() || reg_str[0] != 'R') {
        throw std::invalid_argument("Invalid register format");
    }
    return std::stoi(reg_str.substr(1));
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <instruction_file>" << std::endl;
        return 1;
    }

    std::ifstream inst_file(argv[1]);
    if (!inst_file) {
        std::cerr << "Error: Instruction file not found at " << argv[1] << std::endl;
        return 1;
    }

    int num_arch_regs = 8;
    int num_phys_regs = 16;
    RAT rat(num_arch_regs, num_phys_regs);

    std::cout << "Initialized RAT with " << num_arch_regs << " architectural and " << num_phys_regs << " physical registers." << std::endl;
    std::cout << "Initial State: " << rat.to_string() << std::endl << std::endl;

    std::string line;
    int line_num = 0;
    while (std::getline(inst_file, line)) {
        std::string original_line = trim(line);
        if (original_line.empty() || original_line[0] == '#') {
            continue;
        }

        std::cout << "--- Processing Instruction " << line_num << ": \"" << original_line << "\" ---" << std::endl;

        bool skip_rename = original_line[0] == '!';
        if (skip_rename) {
            line = original_line.substr(1);
            line = ltrim(line);
        }

        std::stringstream ss(line);
        std::string opcode, operands_str;
        ss >> opcode;
        std::getline(ss, operands_str);
        operands_str = trim(operands_str);

        std::vector<std::string> original_operands;
        std::stringstream ops_ss(operands_str);
        std::string op;
        while(std::getline(ops_ss, op, ',')){
            original_operands.push_back(trim(op));
        }

        int dest_reg = -1;
        std::vector<int> source_regs;
        bool is_branch = opcode.rfind("B", 0) == 0;

        try {
            if (!is_branch && !original_operands.empty()) {
                dest_reg = parse_register(original_operands[0]);
                for (size_t i = 1; i < original_operands.size(); ++i) {
                    if (original_operands[i][0] == 'R') {
                        source_regs.push_back(parse_register(original_operands[i]));
                    }
                }
            } else if (is_branch && !original_operands.empty()) {
                for (const auto& operand : original_operands) {
                    if (operand[0] == 'R') {
                        source_regs.push_back(parse_register(operand));
                    }
                }
            }

            std::vector<std::pair<int, int>> phys_sources;
            for (int src : source_regs) {
                int phys_src = rat.get_mapping(src);
                phys_sources.push_back({src, phys_src});
                if (phys_src == -1) {
                    std::cout << "  Source Lookup: ArchReg R" << src << " -> (Not Mapped)" << std::endl;
                } else {
                    std::cout << "  Source Lookup: ArchReg R" << src << " -> PhysReg T" << phys_src << std::endl;
                }
            }

            if (dest_reg != -1 && !skip_rename) {
                auto [old_phys, new_phys] = rat.rename(dest_reg);
                std::cout << "  Destination Rename: ArchReg R" << dest_reg << " -> New PhysReg T" << new_phys << std::endl;
            }
            else if (dest_reg != -1 && skip_rename) {
                 std::cout << "  Skipping rename for destination ArchReg R" << dest_reg << " as instructed by '!'.." << std::endl;
            }

            // Converted instruction
            std::cout << "  Converted: " << opcode;
            std::string converted_ops = "";
            if (!is_branch && dest_reg != -1) {
                int phys_dest = rat.get_mapping(dest_reg);
                converted_ops += (phys_dest == -1 ? " R" + std::to_string(dest_reg) : " T" + std::to_string(phys_dest));
                for (size_t i = 1; i < original_operands.size(); ++i) {
                    converted_ops += ",";
                    if (original_operands[i][0] == 'R') {
                        int arch_reg = parse_register(original_operands[i]);
                        for(const auto& p : phys_sources) {
                            if(p.first == arch_reg) {
                                converted_ops += (p.second == -1 ? " R" + std::to_string(arch_reg) : " T" + std::to_string(p.second));
                                break;
                            }
                        }
                    } else {
                        converted_ops += " " + original_operands[i];
                    }
                }
            } else {
                 for (size_t i = 0; i < original_operands.size(); ++i) {
                    if(i > 0) converted_ops += ",";
                    if (original_operands[i][0] == 'R') {
                        int arch_reg = parse_register(original_operands[i]);
                        for(const auto& p : phys_sources) {
                            if(p.first == arch_reg) {
                                converted_ops += (p.second == -1 ? " R" + std::to_string(arch_reg) : " T" + std::to_string(p.second));
                                break;
                            }
                        }
                    } else {
                        converted_ops += " " + original_operands[i];
                    }
                }
            }
            std::cout << converted_ops << std::endl;

        } catch (const std::exception& e) {
            std::cerr << "  ERROR: " << e.what() << std::endl;
        }

        std::cout << "End of Inst " << line_num << " State: " << rat.to_string() << std::endl << std::endl;
        line_num++;
    }

    return 0;
}
