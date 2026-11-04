#!/usr/bin/env swift
//
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

import AppKit
import Foundation

// Keep in sync with `AppStoreShot` and `ScreenshotTiles` in AppStoreScreenshots.swift. The
// script checks every tile's size, so a mismatch fails instead of producing a bad screenshot.
let shotSize = (width: 1280, height: 800)
let (columns, rows, bleed) = (4, 4, 128)
let scale = 2
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
    let crop = CGRect(
        x: bleedPixels, y: titleBar + bleedPixels, width: tileWidth, height: tileHeight)
    guard let cropped = image.cropping(to: crop) else { throw ScriptError("Can't crop tile") }

    let column = index % columns
    let row = index / columns
    // Core Graphics counts rows from the bottom.
    let origin = CGPoint(x: column * tileWidth, y: (rows - 1 - row) * tileHeight)
    context.draw(
        cropped, in: CGRect(origin: origin, size: CGSize(width: tileWidth, height: tileHeight)))
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
            // Previews occasionally fail to update in place; a second attempt rebuilds.
            let result =
                try (try? client.callTool("RenderPreview", arguments))
                ?? client.callTool("RenderPreview", arguments)
            guard let snapshot = result["snapshot"] as? [String: Any],
                let path = snapshot["path"] as? String
            else {
                throw ScriptError("Preview \(preview) tile \(tile) rendered no snapshot: \(result)")
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
