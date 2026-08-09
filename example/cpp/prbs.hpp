
#pragma once

#include <cstdint>
#include <vector>
#include <cassert>
#include <stdexcept>
#include <algorithm>

class prbs
{
public:
  /**
   * @brief Construct a new prbs generator
   *
   * @param taps Vector with the locations of the taps. Does not have to be ordered.
   * @param seed Initial value to assign to the register.
   * @param invert Whether to invert new bits before shifting in to the register. If true, 0 is a valid state. If false, all 1's is a valid state.
   */
  prbs(const std::vector<std::uint32_t> taps, const std::uint32_t seed = 0, const bool invert = true) : m_taps(taps),
                                                                                                               m_invert(invert),
                                                                                                               m_reg(seed),
                                                                                                               m_reg_mask(0)
  {
    assert(!m_taps.empty());
    m_high_tap = *std::max_element(m_taps.begin(), m_taps.end());
    m_low_tap = *std::min_element(m_taps.begin(), m_taps.end());
    if (m_high_tap > 32)
    {
      throw std::runtime_error("Tap value not supported");
    }
    m_reg_mask = (1 << m_high_tap) - 1;
  }

  std::size_t reg_length_bits() const
  {
    return m_high_tap;
  }

  std::uint8_t get_bit()
  {
    advance();
    return m_reg & 0x01;
  }

  void advance()
  {
    std::uint32_t new_bit = m_reg >> (m_taps[0] - 1);
    for (std::size_t i = 1; i < m_taps.size(); ++i)
    {
      new_bit ^= (m_reg >> (m_taps[i] - 1));
    }

    if (m_invert)
    {
      new_bit = ~new_bit;
    }
    new_bit &= 0x01;

    m_reg = (m_reg << 1) | new_bit;
    m_reg = m_reg & m_reg_mask;
  }

  std::uint32_t get_reg() const { return m_reg; }
  void set_reg(const std::uint32_t reg)
  {
    m_reg = reg;
    m_reg &= m_reg_mask;
  }
  std::uint32_t get_word(const std::size_t bits)
  {
    if (bits > m_low_tap)
    {
      throw std::runtime_error("Too many bits requested");
    }
    const std::uint32_t mask = (1 << bits) - 1;

    std::uint32_t new_bits = m_reg >> (m_taps[0] - bits);
    for (std::size_t i = 1; i < m_taps.size(); ++i)
    {
      new_bits ^= (m_reg >> (m_taps[i] - bits));
    }

    if (m_invert)
    {
      new_bits = ~new_bits;
    }
    new_bits &= mask;

    m_reg = (m_reg << bits) | new_bits;
    m_reg = m_reg & m_reg_mask;
    return new_bits;
  }

private:
  std::vector<std::uint32_t> m_taps;
  bool m_invert;
  std::uint32_t m_reg;
  std::uint32_t m_reg_mask;

  std::uint32_t m_high_tap;
  std::uint32_t m_low_tap;
};
