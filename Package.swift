// swift-tools-version:5.9
// 仅用于在命令行（Linux / macOS）跑算法单元测试：swift test
// App 本身请用 PhotoCleaner.xcodeproj（由 project.yml 生成）编译。
import PackageDescription

let package = Package(
    name: "CleanCore",
    targets: [
        .target(name: "CleanCore",
                path: "PhotoCleaner/Core",
                exclude: ["Models.swift", "ImageAnalyzer.swift", "VisionAnalyzer.swift"],
                sources: ["ImageMath.swift", "SimilarityGrouper.swift", "VisionRules.swift", "AnalysisRecord.swift",
                         "AnalysisCache.swift", "CleanLogic.swift"]),
        .testTarget(name: "CleanCoreTests",
                    dependencies: ["CleanCore"],
                    path: "PhotoCleanerTests"),
    ]
)
