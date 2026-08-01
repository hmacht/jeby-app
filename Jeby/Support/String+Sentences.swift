//
//  String+Sentences.swift
//  Jeby
//
//  Trims text to its first N sentences for card previews. A terminator only
//  counts when followed by whitespace/end, so decimals like "2.3 ft" don't split.
//

import Foundation

extension String {
    func firstSentences(_ limit: Int) -> String {
        let chars = Array(self)
        var result = ""
        var count = 0
        for i in chars.indices {
            result.append(chars[i])
            let isTerminator = chars[i] == "." || chars[i] == "!" || chars[i] == "?"
            let nextIsBreak = i == chars.count - 1 || chars[i + 1] == " " || chars[i + 1] == "\n"
            if isTerminator && nextIsBreak {
                count += 1
                if count >= limit { break }
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
