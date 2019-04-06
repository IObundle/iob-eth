#include "iob-eth.h"

void ethInit(void)
{
  // check processor interface
  // write dummy register
  MEMSET(ETHERNET_BASE, ETHERNET_DUMMY, 0xDEADBEEF);

  // read and check result
  if (MEMGET(ETHERNET_BASE, ETHERNET_DUMMY) != 0xDEADBEEF)
    uart_puts("Ethernet dummy reg test failed\n");
}
