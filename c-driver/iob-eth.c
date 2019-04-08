#include "iob-eth.h"

#define MEMSET(base, location, value) (*((volatile int*) (base + (sizeof(int)) * location)) = value)
#define MEMGET(base, location)        (*((volatile int*) (base + (sizeof(int)) * location)))

int ethInit(unsigned int base)
{
  // check processor interface
  // write dummy register
  MEMSET(base, ETH_DUMMY, 0xDEADBEEF);

  // read and check result
  if (MEMGET(base, ETH_DUMMY) != 0xDEADBEEF)
    return -1;
  return 0;
}
