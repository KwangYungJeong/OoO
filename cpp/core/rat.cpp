#include "rat.hpp"
#include <stdexcept>
#include <algorithm>
#include <sstream>

RAT::RAT(int num_arch_regs, int num_phys_regs, bool init_map, 
         const std::string& arch_reg_prefix, const std::string& phys_reg_prefix)
    : num_arch_regs_(num_arch_regs),
      num_phys_regs_(num_phys_regs),
      arch_reg_prefix_(arch_reg_prefix),
      phys_reg_prefix_(phys_reg_prefix) {

    if (num_phys_regs < num_arch_regs) {
        throw std::invalid_argument("Number of physical registers must be greater than or equal to the number of architectural registers.");
    }

    if (init_map) {
        mapping_.resize(num_arch_regs);
        std::iota(mapping_.begin(), mapping_.end(), 0);
        free_list_.resize(num_phys_regs - num_arch_regs);
        std::iota(free_list_.begin(), free_list_.end(), num_arch_regs);
    } else {
        mapping_.assign(num_arch_regs, -1);
        free_list_.resize(num_phys_regs);
        std::iota(free_list_.begin(), free_list_.end(), 0);
    }
}

int RAT::get_mapping(int arch_reg) const {
    if (arch_reg < 0 || arch_reg >= num_arch_regs_) {
        throw std::out_of_range("Invalid architectural register");
    }
    return mapping_[arch_reg];
}

std::pair<int, int> RAT::rename(int arch_reg_dest, int new_phys_reg_manual) {
    if (arch_reg_dest < 0 || arch_reg_dest >= num_arch_regs_) {
        throw std::out_of_range("Invalid architectural register");
    }

    int old_phys_reg = mapping_[arch_reg_dest];
    int new_phys_reg;

    if (new_phys_reg_manual == -1) { // Automatic allocation
        if (free_list_.empty()) {
            throw std::runtime_error("No free physical registers available");
        }
        new_phys_reg = free_list_.front();
        free_list_.erase(free_list_.begin());
    } else { // Manual allocation
        auto it = std::find(free_list_.begin(), free_list_.end(), new_phys_reg_manual);
        if (it == free_list_.end()) {
            throw std::runtime_error("Requested physical register is not available");
        }
        new_phys_reg = *it;
        free_list_.erase(it);
    }

    mapping_[arch_reg_dest] = new_phys_reg;
    return {old_phys_reg, new_phys_reg};
}

void RAT::free_physical_register(int phys_reg) {
    if (phys_reg < 0 || phys_reg >= num_phys_regs_) {
        throw std::out_of_range("Invalid physical register");
    }
    auto it = std::find(free_list_.begin(), free_list_.end(), phys_reg);
    if (it != free_list_.end()) {
        throw std::runtime_error("Physical register is already in the free list");
    }
    free_list_.push_back(phys_reg);
    std::sort(free_list_.begin(), free_list_.end());
}

std::string RAT::to_string() const {
    std::stringstream ss;
    ss << "RAT(mapping=[";
    for (int i = 0; i < num_arch_regs_; ++i) {
        ss << arch_reg_prefix_ << i << "->";
        if (mapping_[i] == -1) {
            ss << "N/A";
        } else {
            ss << phys_reg_prefix_ << mapping_[i];
        }
        if (i < num_arch_regs_ - 1) ss << ", ";
    }
    ss << "], free_list=[";
    for (size_t i = 0; i < free_list_.size(); ++i) {
        ss << phys_reg_prefix_ << free_list_[i];
        if (i < free_list_.size() - 1) ss << ", ";
    }
    ss << "])";
    return ss.str();
}
