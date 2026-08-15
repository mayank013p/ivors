import Foundation
import Combine
import Darwin

public final class SystemMonitor: ObservableObject {
    public static let shared = SystemMonitor()

    @Published public var cpuUsage: Double = 0.0
    @Published public var memoryUsageMB: Double = 0.0
    @Published public var memoryPercentage: Double = 0.0
    @Published public var gitBranch: String = "N/A"
    @Published public var dockerStatus: String = "Not Running"

    private var previousCpuInfo: processor_info_array_t?
    private var previousNumCpuInfo: mach_msg_type_number_t = 0
    private var timer: Timer?

    private init() {
        updateStats()
        // Lightweight 4.0s timer interval (avoids high CPU polling when running in background)
        timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }

    public func updateStats() {
        fetchRealCPUUsage()
        fetchRealRAMUsage()
        fetchRealGitBranch()
        fetchRealDockerStatus()
    }

    // MARK: - Real macOS CPU Usage (mach_host_self)
    private func fetchRealCPUUsage() {
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        var cpuInfo: processor_info_array_t?

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &cpuInfo, &numCpuInfo)
        if result == KERN_SUCCESS, let cpuInfo = cpuInfo {
            if let prevInfo = previousCpuInfo {
                var totalInUse: Int32 = 0
                var totalTotal: Int32 = 0

                for i in 0..<Int(numCpus) {
                    let user = cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_USER)] - prevInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_USER)]
                    let system = cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_SYSTEM)] - prevInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_SYSTEM)]
                    let idle = cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_IDLE)] - prevInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_IDLE)]
                    let nice = cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_NICE)] - prevInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_NICE)]

                    let inUse = user + system + nice
                    let total = inUse + idle

                    totalInUse += inUse
                    totalTotal += total
                }

                if totalTotal > 0 {
                    let percent = (Double(totalInUse) / Double(totalTotal)) * 100.0
                    DispatchQueue.main.async {
                        self.cpuUsage = min(max(percent, 0.1), 100.0)
                    }
                }

                let prevSize = MemoryLayout<integer_t>.stride * Int(previousNumCpuInfo)
                let addr = vm_address_t(UInt(bitPattern: prevInfo))
                vm_deallocate(mach_task_self_, addr, vm_size_t(prevSize))
            }

            previousCpuInfo = cpuInfo
            previousNumCpuInfo = numCpuInfo
        }
    }

    // MARK: - Real macOS RAM Usage (host_statistics64)
    private func fetchRealRAMUsage() {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let active = UInt64(vmStats.active_count) * pageSize
            let wired = UInt64(vmStats.wire_count) * pageSize
            let compressed = UInt64(vmStats.compressor_page_count) * pageSize

            let usedBytes = active + wired + compressed
            let usedMB = Double(usedBytes) / (1024.0 * 1024.0)
            let totalRAMBytes = ProcessInfo.processInfo.physicalMemory
            let percent = (Double(usedBytes) / Double(totalRAMBytes)) * 100.0

            DispatchQueue.main.async {
                self.memoryUsageMB = usedMB
                self.memoryPercentage = percent
            }
        }
    }

    // MARK: - Instant File-Based Git Branch (0 Subprocess Overhead)
    private func fetchRealGitBranch() {
        DispatchQueue.global(qos: .utility).async {
            let currentPath = FileManager.default.currentDirectoryPath
            let gitHeadURL = URL(fileURLWithPath: currentPath).appendingPathComponent(".git/HEAD")
            if let content = try? String(contentsOf: gitHeadURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) {
                if content.hasPrefix("ref: refs/heads/") {
                    let branch = String(content.dropFirst("ref: refs/heads/".count))
                    DispatchQueue.main.async { self.gitBranch = branch }
                    return
                } else if !content.isEmpty {
                    let shortHash = String(content.prefix(7))
                    DispatchQueue.main.async { self.gitBranch = shortHash }
                    return
                }
            }

            DispatchQueue.main.async { self.gitBranch = "main" }
        }
    }

    // MARK: - Lightweight Socket Check for Docker Status
    private func fetchRealDockerStatus() {
        DispatchQueue.global(qos: .utility).async {
            let socketPath = "/var/run/docker.sock"
            let userSocketPath = NSString(string: "~/.docker/run/docker.sock").expandingTildeInPath
            
            let isSocketPresent = FileManager.default.fileExists(atPath: socketPath) || FileManager.default.fileExists(atPath: userSocketPath)
            
            if !isSocketPresent {
                DispatchQueue.main.async { self.dockerStatus = "Stopped" }
                return
            }

            // Socket exists, running Docker daemon
            DispatchQueue.main.async { self.dockerStatus = "Active" }
        }
    }
}
