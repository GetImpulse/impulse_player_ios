import Foundation

/// A helper class for handling M3U8 manifest data to fetch supported video qualities.
final class ManifestHelper: Sendable {
    
    /// Constants used for parsing the M3U8 manifest.
    private enum Constants {
        static let bandwidth = "BANDWIDTH"
        static let resolution = "RESOLUTION"
    }

    /// An array to store the video qualities.
    func fetchSupportedVideoQualities(with url: URL) async throws -> [VideoQuality] {
        let session = URLSession.shared
        let urlRequest = URLRequest(url: url)
        
        let (data, response) = try await session.data(for: urlRequest)
        return fetchSupportedVideoQualities(with: data) ?? []
    }

    /// Fetches supported video qualities from the provided M3U8 manifest data.
    ///
    /// - Parameter data: The M3U8 manifest data.
    /// - Returns: An array of `VideoQuality` objects representing the supported qualities.
    private func fetchSupportedVideoQualities(with data: Data) -> [VideoQuality] {
        var qualities = handleManifest(data: data)
        qualities.sortAndInsertAutoVideoQualityOption()
        return qualities
    }

    /// Handles the M3U8 manifest data by parsing it to extract video qualities.
    ///
    /// - Parameter data: The M3U8 manifest data.
    private func handleManifest(data: Data) -> [VideoQuality] {
        guard let stringData = String(data: data, encoding: .utf8) else {
            return []
        }
        
        return parse(stringData: stringData)
    }

    /// Parses the string representation of the M3U8 manifest to extract video qualities.
    ///
    /// - Parameter stringData: The string representation of the M3U8 manifest.
    /// - Returns: An array of `VideoQuality` objects.
    private func parse(stringData: String) -> [VideoQuality] {
        var result: [VideoQuality] = []
        let rows = stringData.components(separatedBy: "\n")

        for row in rows {
            if let quality = quality(from: row) {
                if let index = result.firstIndex(where: { $0.resolution == quality.resolution }) {
                    if result[index].bitrate < quality.bitrate {
                        result.remove(at: index)
                        result.append(quality)
                    }
                } else {
                    result.append(quality)
                }
            }
        }
        return result
    }

    /// Extracts a `VideoQuality` object from a single row of the M3U8 manifest.
    ///
    /// - Parameter segments: A single row of the M3U8 manifest.
    /// - Returns: A `VideoQuality` object if parsing is successful, otherwise `nil`.
    private func quality(from segments: String) -> VideoQuality? {
        let dataSegments = segments.components(separatedBy: ",")

        if let bandwidthSegments = dataSegments.first(where: { $0.contains(Constants.bandwidth) }),
           let resolutionSegments = dataSegments.first(where: { $0.contains(Constants.resolution) }) {
            
            let bandwidth = bandwidthSegments.components(separatedBy: "=")
            let resolution = resolutionSegments.components(separatedBy: "=")

            if bandwidth.count > 1, resolution.count > 1,
               let bitrate = Double(bandwidth[1]),
               let resolution = prettyResolution(from: resolution[1]) {
                return VideoQuality(bitrate: bitrate, resolution: resolution)
            }
        }

        return nil
    }

    /// Converts a resolution string from the M3U8 manifest into a more readable format.
    ///
    /// - Parameter resolution: The resolution string from the manifest.
    /// - Returns: A formatted resolution string, or `nil` if the format is invalid.
    private func prettyResolution(from resolution: String) -> String? {
        let resolutionSegments = resolution.lowercased().components(separatedBy: "x")

        if resolutionSegments.count > 1 {
            return resolutionSegments[1].trimmingCharacters(in: .whitespacesAndNewlines) + "p"
        }

        return nil
    }
}
