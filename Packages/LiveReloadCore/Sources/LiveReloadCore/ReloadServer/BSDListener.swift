import Darwin
import Foundation

enum BSDListenerError: Error, Equatable, Sendable {
    case socketCreationFailed
    case addressInUse
    case bindFailed
    case listenFailed
}

final class BSDListener: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.livereload.server.listener")
    private let lock = NSLock()
    private let onAccept: @Sendable (Int32) -> Void
    private var descriptor: Int32
    private var source: DispatchSourceRead?
    private var stopped = false
    private(set) var port: UInt16 = 0

    init(port requestedPort: UInt16, onAccept: @escaping @Sendable (Int32) -> Void) throws {
        self.onAccept = onAccept
        descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw BSDListenerError.socketCreationFailed }

        var reuseAddress: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuseAddress, socklen_t(MemoryLayout<Int32>.size))
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = requestedPort.bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            let bindError = errno
            Darwin.close(descriptor)
            descriptor = -1
            throw bindError == EADDRINUSE ? BSDListenerError.addressInUse : BSDListenerError.bindFailed
        }
        guard Darwin.listen(descriptor, 32) == 0 else {
            Darwin.close(descriptor)
            descriptor = -1
            throw BSDListenerError.listenFailed
        }
        var boundAddress = sockaddr_in()
        var boundLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(descriptor, $0, &boundLength)
            }
        }
        guard nameResult == 0 else {
            Darwin.close(descriptor)
            descriptor = -1
            throw BSDListenerError.bindFailed
        }
        port = UInt16(bigEndian: boundAddress.sin_port)
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK)
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptAvailableConnections() }
        self.source = source
        source.resume()
    }

    func stop() {
        let resources: (DispatchSourceRead?, Int32) = lock.withLock {
            guard !stopped else { return (nil, -1) }
            stopped = true
            let resources = (source, descriptor)
            source = nil
            descriptor = -1
            return resources
        }
        resources.0?.cancel()
        if resources.1 >= 0 {
            Darwin.shutdown(resources.1, SHUT_RDWR)
            Darwin.close(resources.1)
        }
    }

    private func acceptAvailableConnections() {
        let listener = lock.withLock { stopped ? -1 : descriptor }
        guard listener >= 0 else { return }
        while true {
            var address = sockaddr_in()
            var length = socklen_t(MemoryLayout<sockaddr_in>.size)
            let client = withUnsafeMutablePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.accept(listener, $0, &length)
                }
            }
            if client < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK { return }
                return
            }
            _ = fcntl(client, F_SETFL, fcntl(client, F_GETFL) | O_NONBLOCK)
            var noSignal: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
            onAccept(client)
        }
    }

    deinit { stop() }
}
