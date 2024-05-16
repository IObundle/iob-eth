/*
* Python wrapper for CAP_NET_RAW capability
*/
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/prctl.h>
#include <sys/capability.h>

int main(int argc, char *argv[]) {
    // Set CAP_NET_RAW capability
    cap_t caps = cap_get_proc();
    cap_set_flag(caps, CAP_EFFECTIVE, 1, (cap_value_t []){CAP_NET_RAW}, CAP_SET);
    if (cap_set_proc(caps) == -1) {
        perror("cap_set_proc");
        return 1;
    }
    cap_free(caps);

    // CAP_NET_RAW capability is already set, proceed to execute 'python' with provided arguments
    execvp("python", argv);
    perror("execvp");
    return 1;
}
