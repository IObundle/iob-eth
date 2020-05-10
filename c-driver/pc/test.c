/*
 File for testing local socket communication with eth_comm.py script
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

#define SOCKET_NAME "./tmpLocalSocket"
#define BUFFER_SIZE 100


int main(int argc, char* argv[]){
  struct sockaddr_un name;
  
  int connection_socket = 0;
  int ret = 0;
  int data_socket = 0;

  char buffer[BUFFER_SIZE];

  /* remove socket if it exists*/
  unbind(SOCKET_NAME);

  /*create socket to receive connections */
  connection_socket = socket(AF_UNIX, SOCK_STREAM, 0x0800);
  /* check for errors */
  if(connection_socket == -1){
    perror("Failed to create socket");
    exit(EXIT_FAILURE);
  }
  /*clear structure*/
  memset(&name, 0, sizeof(struct sockaddr_un));


  /*bind socket*/
  name.sun_family = AF_UNIX;
  strncpy(name.sun_path, SOCKET_NAME, sizeof(name.sun_path) - 1);

  ret = bind(connection_socket, (const struct sockaddr*) &name, sizeof(struct sockaddr_un));
  /* check for errors */
  if(ret == -1){
    perror("Failed to bind socket");
    exit(EXIT_FAILURE);
  }

  /* wait for eth_comm connections */
  ret = listen(connection_socket, 1);
  /* check for errors */
  if(ret == -1){
    perror("Error in listen");
    exit(EXIT_FAILURE);
  }

  /* accept connection */
  data_socket = accept(connection_socket, NULL, NULL);
  /* check for errors */
  if(data_socket == -1){
    perror("Failed to accept connection");
    exit(EXIT_FAILURE);
  }

  /* receive data */
  ret = read(data_socket, buffer, BUFFER_SIZE);
  /* check for errors */
  if(ret == -1){
    perror("Failed in read()");
    exit(EXIT_FAILURE);
  }

  printf("Received data:\n%s\n\n", buffer);

  /* send data */
  printf("Sending data...");

  sprintf(buffer, "Hello from FPGA!");

  ret = write(data_socket, buffer, BUFFER_SIZE);
  /* check for errors */
  if(ret == -1){
    perror("Failed in write()");
    exit(EXIT_FAILURE);
  }

  printf("...done.");

  /* close socket */
  close(data_socket);

  /* close connection_socket */
  close(connection_socket);

  /* unlink the socket */
  unlink(SOCKET_NAME);
  
  return EXIT_SUCCESS;
}
