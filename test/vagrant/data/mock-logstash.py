import socket
import json

# Script to mock a Node Exporter process on a host

def main():
    host = ''
    port = 5141
    
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((host, port))
        s.listen()
        print("Listening on port", port)
        
        while True:
            conn, addr = s.accept()
            with conn:
                print("Received connection from", addr[0])
                response = {"status": "ok"}
                http_response = "HTTP/1.1 200 OK\n"
                http_response += "Content-Type: application/json\n"
                http_response += "\n"
                http_response += json.dumps(response)
                conn.sendall(http_response.encode())

if __name__ == '__main__':
    main()
