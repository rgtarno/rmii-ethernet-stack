
#pragma once

#include <cstdint>

#include "rmii_mac_comp.hpp"
#include "reg_interface.hpp"
#include "lan8720.hpp"


class rmii_ethernet
{
public:
    rmii_ethernet(reg_interface& reg_interface, const std::uint32_t offset);

    struct status_t
    {
        std::uint32_t bytes_sent = 0;
        std::uint32_t packets_sent = 0;
        std::uint32_t bytes_received = 0;
        std::uint32_t packets_received = 0;
        std::uint16_t fcs_fails = 0;
        std::uint16_t ethernet_packets_dropped = 0;
        lan8720::speed_t link_speed = lan8720::speed_t::UNKNOWN;
        bool link_up = false;
    };


    bool init(bool auto_negotiate = true);
    status_t get_status();
    void set_source_mac(const unsigned char addr[6]);
    void set_destination_mac(const unsigned char addr[6]);
    void set_source_ip(std::uint32_t ip);
    void send_arp();

    void dump_phy_regs();

private:

    bool phy_autonegotiate();
    bool is_autonegotiation_complete();
    bool find_phy_address(std::uint16_t& phy_addr);

    rmii_mac_comp _mac;
    std::uint16_t _phy_address;
};