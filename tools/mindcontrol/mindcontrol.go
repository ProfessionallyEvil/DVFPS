package main

import (
	"bytes"
	"encoding/binary"
	"flag"
	"log"
	"net"
	"os"
	"strconv"
	"strings"
)

const MAX_HREADS = 20
const MAX_BUF_SIZE = 4096

var proxyConn *net.UDPConn  // this is the connection that clients will send packets to
var serverAddr *net.UDPAddr // the upstream server to connect to
// we need to "lay" a connection ontop of UDP so that we can shove packets back and forth where they need to go
type Connection struct {
	ClientAddr *net.UDPAddr
	ServerConn *net.UDPConn
}

// "ip" -> *Connection{ ClientAddr, ServerAddr }
var clientDict map[string]*Connection = make(map[string]*Connection)

// Hold discovered IDs
var clientIds []string

func decodeUint64(buf []byte) uint64 {
	// https://github.com/godotengine/godot/blob/8f7f5846397297fff6e8a08f89bc60ce658699cc/core/io/marshalls.h#L149
	u := uint64(0)

	for i := int(0); i < 8; i++ {
		b := uint64(buf[i] & 0xFF)
		b <<= (i * 8)
		u |= b
	}

	return u
}

func encodeUint64(num uint64, buf *[]byte) {
	for i := int(0); i < 8; i++ {
		(*buf)[0] = byte(num & 0xFF)
		num >>= 8
	}
}

// stub
func extractClientIDs(conn net.UDPConn) ([]byte, error) {
	/*
		Example client ID in packet
		02 00 00 00 8c 9e 7a 15

		02 00 00 00 - tell's us that the following 4 bytes represent an integer
		8c 9e 7a 15 - this is the integer value that we need to decode, it's in little endian format.

		Once we extract those 4 bytes from the correct incoming packet we can decode the byte slice like so

		clientIDBytes := getClientIDBytes(buf)
		// we may need to do some checking to see if it's really
		binary.LittleEndian.Uint64(clientIDBytes)
	*/
	return nil, nil
}

func isCreatePlayerPacket(buf []byte) uint32 {
	// uint32(0) if not found, extracted id otherwise (hopefully)
	// do the checks
	var clientIDStart int
	var clientIDEnd int
	clientID := uint32(0)
	clientIDKeyIndex := bytes.Index(buf, []byte("client_id"))

	if clientIDKeyIndex > -1 {
		clientIDStart = clientIDKeyIndex + 9 + 8 - 1
		clientIDEnd = clientIDKeyIndex + 9 + 8 + 4 - 1

		// extract the ID
		clientID = binary.LittleEndian.Uint32(buf[clientIDStart:clientIDEnd])
	}
	return clientID
}

func forward(conn net.UDPConn, toAddr *net.UDPAddr, fromBuf []byte) {
	n, err := conn.WriteToUDP(fromBuf[:cap(fromBuf)], toAddr)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("forwarding packet: bytes=%d to=%s", n, toAddr.String())
}

func newConnection(serverAddr, clientAddr *net.UDPAddr) *Connection {
	conn := new(Connection)
	conn.ClientAddr = clientAddr
	serverConn, err := net.DialUDP("udp", nil, serverAddr)
	if err != nil {
		log.Fatalln(err)
	}
	conn.ServerConn = serverConn
	return conn
}

func runConnection(conn *Connection) {
	buf := make([]byte, MAX_BUF_SIZE)
	for {
		// Read from server
		n, err := conn.ServerConn.Read(buf)

		if err != nil {
			log.Fatalln(err)
		}
		// Is the packet instantiating player puppets?
		if clientID := isCreatePlayerPacket(buf); clientID > 0 {
			log.Printf("EXTRACTED CLIENT_ID=%d", clientID)
		}
		// log.Printf("received-packet bytes=%d from=%s\n", n, serverAddr.String())
		// log.Printf("\n%s\n", hex.Dump(buf[:n]))
		// relay to client
		_, err = proxyConn.WriteToUDP(buf[:n], conn.ClientAddr)
		if err != nil {
			// don't kill over just keep going but report the error using log for now
			log.Println(err)
		}
		// log.Printf("relayed-packet: bytes=%d to=%s\n", n, conn.ClientAddr.String())
	}
}

func proxy(conn *net.UDPConn) {
	buf := make([]byte, MAX_BUF_SIZE)
	n, fromAddr, err := 0, new(net.UDPAddr), error(nil)
	for err == nil {
		// try to read from the listener
		n, fromAddr, err = conn.ReadFromUDP(buf)

		// is this a new connection?
		conn, found := clientDict[fromAddr.String()]
		if !found {
			// initialize connection information
			conn = newConnection(serverAddr, fromAddr)
			clientDict[fromAddr.String()] = conn

			// run new connection in goroutine
			go runConnection(conn)
		}

		// log.Printf("packet-received: bytes=%d from=%s\n", n, fromAddr.String())
		if err != nil {
			log.Fatalln(err)
		}

		// log.Printf("\n%s\n", hex.Dump(buf[:n]))

		// relay to server
		_, err = conn.ServerConn.Write(buf[:n])

		// manually clear the buffer slice (might consider using bytes.Buffer going forward)
		for i, _ := range buf {
			buf[i] = 0
		}
	}
}

func main() {
	var showHelp *bool = flag.Bool("h", false, "Show help information")
	var serverAddrString *string = flag.String("s", "", "The upstream address and port to proxy to, format=<ip>:<port>")
	var proxyAddrString *string = flag.String("p", "127.0.0.1:1337", "The address and port to listen on, defaul='127.0.0.1:1337'")
	flag.Parse()

	if *showHelp {
		flag.Usage()
		os.Exit(0)
	}

	// if flag.NArg() > 0 {
	// }

	serverAddrSlice := strings.Split(*serverAddrString, ":")
	serverAddrIP := net.ParseIP(serverAddrSlice[0])
	if serverAddrIP == nil {
		flag.Usage()
		log.Fatalln("Invalid IP format")
	}
	serverAddrPort, err := strconv.Atoi(serverAddrSlice[1])
	if err != nil {
		flag.Usage()
		log.Fatalln("Port must be an integer")
	}
	serverAddr = &net.UDPAddr{
		Port: serverAddrPort,
		IP:   serverAddrIP,
	}

	proxyAddrSlice := strings.Split(*proxyAddrString, ":")
	proxyAddrIP := net.ParseIP(proxyAddrSlice[0])
	if proxyAddrIP == nil {
		flag.Usage()
		log.Fatalln("Invalid IP format")
	}

	proxyAddrPort, err := strconv.Atoi(proxyAddrSlice[1])
	if err != nil {
		flag.Usage()
		log.Fatalln("Port must be an integer")
	}

	// bind to UDP port 1337 on all interfaces
	proxyAddr := net.UDPAddr{
		Port: proxyAddrPort,
		IP:   proxyAddrIP,
	}
	proxyConn, err = net.ListenUDP("udp", &proxyAddr)
	if err != nil {
		log.Fatal(err)
	}

	log.Printf("Listening on %s\nProxying to %s", proxyAddr.String(), serverAddr.String())
	proxy(proxyConn)
}
