
#include "prbs_verifier.hpp"


///////////////////////////////////////////////////////
prbs_verifier::prbs_verifier(const std::vector<std::uint32_t> taps, const bool invert) : 
    m_state{state_t::INIT},
    m_init_reg{0},
    m_lock_threshold{2048},
    m_unlock_threshold{128},
    m_sucess_counter{0},
    m_prbs(taps, 0, invert),
    m_status{}
{
};

///////////////////////////////////////////////////////
void prbs_verifier::push_bits(std::uint32_t reg, const std::size_t num_bits)
{
    const std::uint32_t reg_mask = (1 << num_bits) - 1;
    reg = reg & reg_mask;

    switch (m_state)
    {
        case state_t::INIT:
        {
            m_init_reg = (m_init_reg << num_bits) | reg;
            m_status.num_bits += num_bits;
            if (m_status.num_bits >= m_prbs.reg_length_bits())
            {
                m_prbs.set_reg(m_init_reg);
                m_state = state_t::LOCKING;
            }
            break;
        }
        case state_t::LOCKING:
        {
            const int num_errors = __builtin_popcount(reg ^ m_prbs.get_word(num_bits));

            m_status.num_bits += num_bits;
            if (num_errors)
            {
                m_status.num_bit_errors += num_errors;
                m_sucess_counter = 0;
            }
            else
            {
                m_sucess_counter += num_bits;
            }
            if (m_sucess_counter >= m_lock_threshold)
            {
                m_status.locked = true;
                m_status.lock_count += 1;
                m_state = state_t::LOCKED;
            }
            break;
        }
        case state_t::LOCKED:
        {
            m_status.num_bits += num_bits;
            const int num_errors = __builtin_popcount(reg ^ m_prbs.get_word(num_bits));
            if (num_errors)
            {
                m_status.num_bit_errors += num_errors;
            }
            if (m_status.num_bit_errors >= m_unlock_threshold)
            {
                m_status.num_bits = 0;
                m_status.locked = false;
                m_status.num_bit_errors = 0;
                m_state = state_t::LOCKING;
            }
            break;
        }
    }
}

///////////////////////////////////////////////////////
void prbs_verifier::push_bit(const bool bit)
{
    switch (m_state)
    {
        case state_t::INIT:
        {
            m_init_reg = (m_init_reg << 1) | bit;
            m_status.num_bits += 1;
            if (m_status.num_bits >= m_prbs.reg_length_bits())
            {
                m_prbs.set_reg(m_init_reg);
                m_state = state_t::LOCKING;
            }
            break;
        }
        case state_t::LOCKING:
        {
            const bool error = (bit != m_prbs.get_bit());

            m_status.num_bits += 1;
            if (error)
            {
                m_status.num_bit_errors += 1;
                m_sucess_counter = 0;
            }
            else
            {
                m_sucess_counter += 1;
            }
            if (m_sucess_counter >= m_lock_threshold)
            {
                m_status.locked = true;
                m_status.lock_count += 1;
                m_state = state_t::LOCKED;
            }
            break;
        }
        case state_t::LOCKED:
        {
            m_status.num_bits += 1;
            const bool error = (bit != m_prbs.get_bit());
            if (error)
            {
                m_status.num_bit_errors += 1;
            }
            if (m_status.num_bit_errors >= m_unlock_threshold)
            {
                m_status.num_bits = 0;
                m_status.locked = false;
                m_status.num_bit_errors = 0;
                m_state = state_t::LOCKING;
            }
            break;
        }
    }
}

///////////////////////////////////////////////////////
void prbs_verifier::reset()
{
    m_status = status_t();
    m_sucess_counter = 0;
    m_state = state_t::INIT;
}

///////////////////////////////////////////////////////
void prbs_verifier::set_lock_threshold(const std::uint64_t num_bits)
{
    m_lock_threshold = num_bits;
}

///////////////////////////////////////////////////////
void prbs_verifier::set_unlock_threshold(const std::uint64_t num_bits)
{
    m_unlock_threshold = num_bits;
}

///////////////////////////////////////////////////////
prbs_verifier::status_t prbs_verifier::get_status() const
{
    return m_status;
}
