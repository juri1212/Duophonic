#!/usr/bin/env swift
import AppKit
import Foundation

// Renders the App Store screenshots in Duophonic/Marketing/AppStoreScreenshots.swift through
// Xcode's previews and writes them as 2560 × 1600 PNGs to appstore/screenshots/en-US.
//
// Xcode's preview canvas only renders about 1500 × 975 pixels at full resolution, so each
// screenshot preview is rendered in tiles (one per preview argument) that this script crops
// and stitches. It talks to Xcode through its MCP server, `xcrun mcpbridge`.
//
// Usage, with Xcode running:
//   swift scripts/export-app-store-screenshots.swift [screenshot number…]
// Without numbers it exports all of them.
//
// The first time, Xcode asks to allow the connection.
//
// The imports stay above this comment: swift-format joins a comment that follows the shebang
// onto the shebang's line, which breaks it.

// Keep in sync with `AppStoreShot` and `ScreenshotTiles` in AppStoreScreenshots.swift. The
// script checks every tile's size, so a mismatch fails instead of producing a bad screenshot.
let shotSize = (width: 1280, height: 800)
let (columns, rows, bleed) = (4, 4, 128)
let scale = 2
/// Half the width of the band in which neighboring tiles are blended, in pixels. Less than
/// the bleed, so the band stays clear of the preview window's rounded corners.
let feather = 64
let sourceFile = "Duophonic/Marketing/AppStoreScreenshots.swift"

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let outputDirectory = root.appending(path: "appstore/screenshots/en-US")

// MARK: - MCP client

struct ScriptError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

final class MCPClient {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private var buffer = Data()
    private var nextID = 1

    init() throws {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["mcpbridge"]
        process.standardInput = input
        process.standardOutput = output
        try process.run()

        _ = try request(
            "initialize",
            params: [
                "protocolVersion": "2025-06-18",
                "capabilities": [:] as [String: Any],
                "clientInfo": ["name": "export-app-store-screenshots", "version": "1"],
            ])
        try send(["jsonrpc": "2.0", "method": "notifications/initialized"])
    }

    deinit { process.terminate() }

    /// Calls an Xcode tool and returns its result, which Xcode encodes as JSON text.
    func callTool(_ name: String, _ arguments: [String: Any]) throws -> [String: Any] {
        let result = try request("tools/call", params: ["name": name, "arguments": arguments])
        let text = ((result["content"] as? [[String: Any]])?.first?["text"] as? String) ?? ""
        if result["isError"] as? Bool == true {
            throw ScriptError("\(name) failed: \(text.prefix(2000))")
        }
        guard let data = text.data(using: .utf8),
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw ScriptError("\(name) returned an unexpected result: \(text.prefix(500))") }
        return json
    }

    private func request(_ method: String, params: [String: Any]) throws -> [String: Any] {
        let id = nextID
        nextID += 1
        try send(["jsonrpc": "2.0", "id": id, "method": method, "params": params])
        while true {
            let message = try readMessage()
            guard message["id"] as? Int == id else { continue }  // Notifications and logs.
            if let error = message["error"] as? [String: Any] {
                throw ScriptError("\(method) failed: \(error["message"] ?? error)")
            }
            return message["result"] as? [String: Any] ?? [:]
        }
    }

    private func send(_ message: [String: Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(0x0A)
        input.fileHandleForWriting.write(data)
    }

    private func readMessage() throws -> [String: Any] {
        while true {
            if let newline = buffer.firstIndex(of: 0x0A) {
                let line = buffer[buffer.startIndex..<newline]
                buffer.removeSubrange(buffer.startIndex...newline)
                if let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any] {
                    return json
                }
                continue
            }
            let chunk = output.fileHandleForReading.availableData
            if chunk.isEmpty { throw ScriptError("mcpbridge exited. Is Xcode running?") }
            buffer.append(chunk)
        }
    }
}

// MARK: - Images

func loadImage(_ path: String) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw ScriptError("Can't read \(path)") }
    return image
}

/// Draws a rendered tile into the screenshot, without the preview window's title bar above it
/// and the bleed around it.
///
/// Liquid Glass adapts to everything behind it, so a window comes out a few levels lighter or
/// darker in one tile than in the next, which would show as a faint line where they meet.
/// Each tile is therefore drawn `feather` pixels into its neighbors, and fades in over the
/// tiles drawn before it, to its left and above. Text and edges are the same in both tiles,
/// so the blend only smooths the glass.
func draw(tile path: String, index: Int, into context: CGContext) throws {
    let image = try loadImage(path)
    let tileWidth = shotSize.width / columns * scale
    let tileHeight = shotSize.height / rows * scale
    let bleedPixels = bleed * scale
    let expectedWidth = tileWidth + 2 * bleedPixels
    let titleBar = image.height - (tileHeight + 2 * bleedPixels)
    guard image.width == expectedWidth, (0...120).contains(titleBar) else {
        throw ScriptError(
            "Tile \(index) is \(image.width) × \(image.height) px, expected \(expectedWidth) px wide. "
                + "The canvas scaled it down, or the grid differs from AppStoreScreenshots.swift.")
    }

    let column = index % columns
    let row = index / columns
    let left = column > 0 ? feather : 0
    let top = row > 0 ? feather : 0
    let width = tileWidth + left + (column < columns - 1 ? feather : 0)
    let height = tileHeight + top + (row < rows - 1 ? feather : 0)
    let crop = CGRect(
        x: bleedPixels - left, y: titleBar + bleedPixels - top, width: width, height: height)
    guard let cropped = image.cropping(to: crop) else { throw ScriptError("Can't crop tile") }

    // Opaque, except for a ramp across the band shared with the tile to the left and above.
    var opacity = [UInt8](repeating: 255, count: width * height)
    for y in 0..<(2 * top) {
        for x in 0..<width {
            opacity[y * width + x] = UInt8((Double(y) + 0.5) / Double(2 * top) * 255)
        }
    }
    for x in 0..<(2 * left) {
        let ramp = (Double(x) + 0.5) / Double(2 * left)
        for y in 0..<height {
            opacity[y * width + x] = UInt8(Double(opacity[y * width + x]) * ramp)
        }
    }
    guard let provider = CGDataProvider(data: Data(opacity) as CFData),
        let mask = CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent)
    else { throw ScriptError("Can't create the mask for tile \(index)") }

    // Core Graphics counts rows from the bottom.
    let rect = CGRect(
        x: column * tileWidth - left, y: (rows - row) * tileHeight + top - height,
        width: width, height: height)
    context.saveGState()
    context.clip(to: rect, mask: mask)
    context.draw(cropped, in: rect)
    context.restoreGState()
}

/// Whether a rendered tile is one flat color. Now and then Xcode takes the snapshot before
/// the preview has drawn, which leaves a white hole in the screenshot. No real tile is flat:
/// even one with only wallpaper on it has a gradient.
func isBlank(_ path: String) throws -> Bool {
    let image = try loadImage(path)
    let side = 8
    var pixels = [UInt8](repeating: 0, count: side * side * 4)
    guard
        let context = CGContext(
            data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
        // Without the title bar, which is never blank.
        let content = image.cropping(
            to: CGRect(x: 0, y: image.height / 4, width: image.width, height: image.height * 3 / 4))
    else { throw ScriptError("Can't inspect \(path)") }
    context.draw(content, in: CGRect(x: 0, y: 0, width: side, height: side))
    return (0..<(side * side)).allSatisfy { pixel in
        (0..<3).allSatisfy { abs(Int(pixels[pixel * 4 + $0]) - Int(pixels[$0])) <= 1 }
    }
}

func writePNG(_ context: CGContext, to url: URL) throws {
    guard let image = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(
            url as CFURL, "public.png" as CFString, 1, nil)
    else { throw ScriptError("Can't write \(url.path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw ScriptError("Can't write \(url.path)")
    }
}

func fileName(for displayName: String) -> String {
    displayName.lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-")) + ".png"
}

// MARK: - Export

func export() throws {
    let client = try MCPClient()
    let workspace = try client.callTool(
        "XcodeOpenWorkspace", ["path": root.appending(path: "Duophonic.xcodeproj").path])
    guard let workspaceID = workspace["workspaceIdentifier"] as? String else {
        throw ScriptError("XcodeOpenWorkspace returned no workspace identifier")
    }

    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    let previewCount =
        try String(contentsOf: root.appending(path: sourceFile), encoding: .utf8)
        .components(separatedBy: "#Preview(").count - 1

    let requested = CommandLine.arguments.dropFirst().compactMap { Int($0) }.map { $0 - 1 }
    for preview in 0..<previewCount where requested.isEmpty || requested.contains(preview) {
        // Group item 0 is the whole screenshot; 1… are the tiles in reading order.
        var tiles: [String] = []
        var displayName = "\(preview + 1)"
        for tile in 0..<(columns * rows) {
            let arguments: [String: Any] = [
                "workspaceIdentifier": workspaceID,
                "sourceFilePath": sourceFile,
                "previewDefinitionIndexInFile": preview,
                "previewCanvasControlOverrides": ["groupItemIndex": tile + 1],
                "timeout": 300,
            ]
            // Previews occasionally fail to update in place, or come back blank; another
            // attempt rebuilds.
            var rendered: (result: [String: Any], path: String)?
            var failure: Error?
            for _ in 1...3 where rendered == nil {
                do {
                    let result = try client.callTool("RenderPreview", arguments)
                    guard let snapshot = result["snapshot"] as? [String: Any],
                        let path = snapshot["path"] as? String
                    else {
                        throw ScriptError(
                            "Preview \(preview) tile \(tile) rendered no snapshot: \(result)")
                    }
                    if try isBlank(path) {
                        throw ScriptError("Preview \(preview) tile \(tile) rendered blank")
                    }
                    rendered = (result, path)
                } catch {
                    failure = error
                }
            }
            guard let (result, path) = rendered else {
                throw failure ?? ScriptError("Preview \(preview) tile \(tile) didn't render")
            }
            displayName = result["displayName"] as? String ?? displayName
            tiles.append(path)
            print("Rendered \(displayName), tile \(tile + 1) of \(columns * rows)")
        }

        let colorSpace =
            (try? loadImage(tiles[0]).colorSpace) ?? CGColorSpace(name: CGColorSpace.displayP3)!
        // Opaque, as App Store Connect asks for screenshots without an alpha channel.
        guard
            let context = CGContext(
                data: nil, width: shotSize.width * scale, height: shotSize.height * scale,
                bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw ScriptError("Can't create the screenshot bitmap") }
        for (index, path) in tiles.enumerated() {
            try draw(tile: path, index: index, into: context)
        }
        let url = outputDirectory.appending(path: fileName(for: displayName))
        try writePNG(context, to: url)
        print("Wrote \(url.path)")
    }
}

do {
    try export()
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
