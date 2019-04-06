#include "iob-eth.h"

void ethInit(unsigned int base)
{
  // check processor interface
  // write dummy register
  MEMSET(base, ETHERNET_DUMMY, 0xDEADBEEF);

  // read and check result
  if (MEMGET(base, ETHERNET_DUMMY) != 0xDEADBEEF)
    uart_puts("Ethernet dummy reg test failed\n");
}
