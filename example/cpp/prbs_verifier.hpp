

#pragma once


#include <cstdint>
#include <vector>

#include "prbs.hpp"




class prbs_verifier
{
public:
    prbs_verifier(const std::vector<std::uint32_t> taps, const bool invert = true);
    ~prbs_verifier() = default;

    void push_bit(const bool bit);
    void push_bits(const std::uint32_t reg, const std::size_t num_bits);

    void reset();

    void set_lock_threshold(const std::uint64_t num_bits);
    void set_unlock_threshold(const std::uint64_t num_bits);

    struct status_t
    {
        std::uint64_t num_bits = 0;
        std::uint64_t num_bit_errors = 0;
        bool locked = false;
        std::uint64_t lock_count = 0;
    };

    status_t get_status() const;

private:

    enum class state_t {INIT, LOCKING, LOCKED};

    state_t m_state;
    std::uint32_t m_init_reg;
    std::uint64_t m_lock_threshold;
    std::uint64_t m_unlock_threshold;
    std::uint64_t m_sucess_counter;
    prbs m_prbs;
    status_t m_status;
};
