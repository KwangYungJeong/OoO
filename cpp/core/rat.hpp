#ifndef RAT_HPP
#define RAT_HPP

#include <vector>
#include <string>
#include <numeric>

class RAT {
public:
    RAT(int num_arch_regs, int num_phys_regs, bool init_map = false, 
        const std::string& arch_reg_prefix = "R", const std::string& phys_reg_prefix = "T");

    int get_mapping(int arch_reg) const;
    std::pair<int, int> rename(int arch_reg_dest, int new_phys_reg = -1);
    void free_physical_register(int phys_reg);
    std::string to_string() const;

private:
    int num_arch_regs_;
    int num_phys_regs_;
    std::string arch_reg_prefix_;
    std::string phys_reg_prefix_;
    std::vector<int> mapping_;
    std::vector<int> free_list_;
};

#endif // RAT_HPP
