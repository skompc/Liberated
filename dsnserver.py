import socket
import sys
from dnslib import DNSRecord, RR, QTYPE, A, AAAA

# Configuration
DOMAIN_NAMES = ["d2-megaten-l.sega.com", "d2r-dl.d2megaten.com", "d2r-sim.d2megaten.com","d2r-chat.d2megaten.com"]
HOST_IPv4 = "0.0.0.0"  # Bind to all IPv4 interfaces
HOST_IPv6 = "::"       # Bind to all IPv6 interfaces
PORT = 53              # Default DNS port

def get_server_ip():
    """Get the server's primary IPv4 and IPv6 addresses."""
    hostname = socket.gethostname()
    ipv4 = socket.gethostbyname(hostname)
    ipv6 = None
    try:
        ipv6 = socket.getaddrinfo(hostname, None, socket.AF_INET6)[0][4][0]
    except Exception:
        pass  # IPv6 might not be configured
    return ipv4, ipv6

def create_response(data, ipv4, ipv6):
    """Create a DNS response for supported domains."""
    request = DNSRecord.parse(data)
    reply = request.reply()
    for question in request.questions:
        qname = str(question.qname).rstrip(".")
        if qname in DOMAIN_NAMES:
            if question.qtype == QTYPE.A and ipv4:
                reply.add_answer(RR(qname, QTYPE.A, rdata=A(ipv4), ttl=60))
            if question.qtype == QTYPE.AAAA and ipv6:
                reply.add_answer(RR(qname, QTYPE.AAAA, rdata=AAAA(ipv6), ttl=60))
    return reply.pack()

def start_dns_server():
    ipv4, ipv6 = get_server_ip()
    print(f"DNS server running on IPv4: {ipv4}, IPv6: {ipv6}")

    # Create sockets for IPv4 and IPv6
    sock_ipv4 = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock_ipv6 = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
    sock_ipv4.bind((HOST_IPv4, PORT))
    sock_ipv6.bind((HOST_IPv6, PORT))

    print("Listening on UDP port 53 for both IPv4 and IPv6")

    while True:
        try:
            # Wait for requests
            rlist, _, _ = select.select([sock_ipv4, sock_ipv6], [], [])
            for sock in rlist:
                data, addr = sock.recvfrom(512)
                response = create_response(data, ipv4, ipv6)
                sock.sendto(response, addr)
        except KeyboardInterrupt:
            print("Shutting down the DNS server...")
            break
        except Exception as e:
            print(f"Error: {e}")

    sock_ipv4.close()
    sock_ipv6.close()

if __name__ == "__main__":
    if sys.platform == "win32":
        import select  # On Windows, `select` must be explicitly imported
    start_dns_server()
