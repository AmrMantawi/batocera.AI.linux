#include <iostream>
#include <string>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <cstring>
#include <cstdio>

class LocalLLMClient {
private:
    int sock_fd;
    struct sockaddr_un addr;
    bool connected;

public:
    LocalLLMClient() : sock_fd(-1), connected(false) {
        memset(&addr, 0, sizeof(addr));
    }

    ~LocalLLMClient() {
        disconnect();
    }

    bool connect(const std::string& socket_path) {
        // Create socket
        sock_fd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (sock_fd == -1) {
            std::cerr << "Failed to create socket" << std::endl;
            return false;
        }

        // Set up address structure
        addr.sun_family = AF_UNIX;
        strncpy(addr.sun_path, socket_path.c_str(), sizeof(addr.sun_path) - 1);

        // Connect to socket
        if (::connect(sock_fd, (struct sockaddr*)&addr, sizeof(addr)) == -1) {
            std::cerr << "Failed to connect to socket: " << socket_path << std::endl;
            close(sock_fd);
            sock_fd = -1;
            return false;
        }

        connected = true;
        return true;
    }

    bool send_request(const std::string& request) {
        if (!connected) return false;
        
        ssize_t sent = send(sock_fd, request.c_str(), request.length(), 0);
        return sent == static_cast<ssize_t>(request.length());
    }

    std::string receive_response() {
        if (!connected) return "";
        
        char buffer[4096];
        ssize_t received = recv(sock_fd, buffer, sizeof(buffer) - 1, 0);
        
        if (received > 0) {
            buffer[received] = '\0';
            return std::string(buffer);
        }
        
        return "";
    }

    bool is_connected() const {
        return connected;
    }

    void disconnect() {
        if (sock_fd != -1) {
            close(sock_fd);
            sock_fd = -1;
        }
        connected = false;
    }
};

// Simple test program
int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cout << "Usage: " << argv[0] << " <message|stream>" << std::endl;
        return 1;
    }

    LocalLLMClient client;
    
    if (!client.connect("/run/local-llm.sock")) {
        std::cerr << "Failed to connect to local-llm service" << std::endl;
        return 1;
    }

    std::string message = argv[1];
    // Ensure newline termination required by the server
    if (message.empty() || message.back() != '\n') {
        message.push_back('\n');
    }

    if (!client.send_request(message)) {
        std::cerr << "Failed to send message" << std::endl;
        return 1;
    }

    // If streaming, continuously print chunks until server closes or user interrupts
    if (message.rfind("stream\n", 0) == 0) {
        while (client.is_connected()) {
            std::string chunk = client.receive_response();
            if (chunk.empty()) break;
            std::cout << chunk << std::flush;
        }
        return 0;
    }

    // One-shot response
    std::string response = client.receive_response();
    std::cout << "Response: " << response << std::endl;

    return 0;
}
