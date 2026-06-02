import Foundation

func normalizeMicroseconds(in dateStr: String) -> String {
    var formattedDateStr = dateStr
    if let dotIndex = formattedDateStr.firstIndex(of: ".") {
        var endIndex = formattedDateStr.index(after: dotIndex)
        while endIndex < formattedDateStr.endIndex, formattedDateStr[endIndex].isNumber {
            endIndex = formattedDateStr.index(after: endIndex)
        }
        let fractionCount = formattedDateStr.distance(from: dotIndex, to: endIndex) - 1
        if fractionCount > 3 {
            let msEndIndex = formattedDateStr.index(dotIndex, offsetBy: 4)
            formattedDateStr.replaceSubrange(msEndIndex..<endIndex, with: "")
        }
    }
    return formattedDateStr
}

let inputs = [
    "2026-06-02T04:32:49.459035+00:00",
    "2026-06-02T04:32:49.459035Z",
    "2026-06-02T04:32:49.459Z",
    "2026-06-02T04:32:49Z",
    "2026-06-02 04:32:49.459035"
]

for input in inputs {
    let normalized = normalizeMicroseconds(in: input)
    print("Input: \(input) -> Normalized: \(normalized)")
}
