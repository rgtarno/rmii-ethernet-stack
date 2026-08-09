

# AFIFO

Based on the Sunburst design paper by Clifford E. Cummings

http://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf

Uses gray codes to communicate read and write pointers between the two clock domains.

Also uses internal LOG_DEPTH+1 wide counters, the extra bit is used to track whether the counters have wrapped, allowing every memory address
in the RAM to be used.