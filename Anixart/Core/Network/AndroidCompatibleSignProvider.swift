import Foundation

struct AndroidCompatibleSignProvider: SignProvider {
    let androidPackageName: String
    let apkCertMd5Hex: String
    let androidSdkInt: Int

    init(
        androidPackageName: String = "com.swiftsoft.anixartd",
        apkCertMd5Hex: String = "9aa5c7af74e8cd70c86f7f9587bde23d",
        androidSdkInt: Int = 32
    ) {
        self.androidPackageName = androidPackageName
        self.apkCertMd5Hex = apkCertMd5Hex
        self.androidSdkInt = androidSdkInt
    }

    func makeSign() -> String {
        let leftSeed = randomAlnum(4)
        let rightSeed = randomAlnum(8)
        let outerDigitShift = Int.random(in: 1...9)

        let partA = randomChars(6, from: "ABCDEFuvwxyz012+!&<)")
        let timestamp = Int64(Date().timeIntervalSince1970)
        let timeBaseNumber = Int64("1" + reverse(String(timestamp)))! + 2112
        let noisyTime = insertNoiseAfterEveryChar(
            String(timeBaseNumber),
            allowed: "NOPQRSTUVWXYZabcdefghijklm56789+!&<)"
        )

        let partB = randomChars(7, from: "GHIJKLopqrst34?^(./")
        let partC = randomChars(4, from: "MNOPQRijklmn56$\\%}@")
        let partDNumber = [99, 74, 49].randomElement()! - 12
        let partE = randomChars(7, from: "STUVWXYZabcdefgh789+]>{?")
        let sdkLastDigit = String(String(androidSdkInt).last!)
        let modeKey = Int.random(in: 10...27)

        let raw = partA + noisyTime + partB + partC + String(partDNumber) + partE + sdkLastDigit + String(modeKey)
        let modeChars = Array(String(modeKey))
        let firstDigit = Int(String(modeChars.first!))!
        let lastDigit = Int(String(modeChars.last!))!
        let sumDigits = firstDigit + lastDigit

        let payload: String
        if firstDigit == 1 {
            payload = base64NoWrap(caesarLetters(shiftDigitsDown(raw, by: sumDigits - 1), by: lastDigit))
                + String(lastDigit)
                + randomChars(2, from: "12345+%<&?")
                + randomChars(1, from: "&{]#@")
        } else {
            payload = caesarLetters(shiftDigitsDown(base64NoWrap(raw), by: sumDigits), by: lastDigit)
                + String(lastDigit)
                + randomChars(2, from: "6789!^>~/")
                + randomChars(1, from: "%}[$^")
        }

        let certPart = caesarLetters(reverse(apkCertMd5Hex), by: countDigits(leftSeed) + 1)
        let packagePart = caesarLetters(androidPackageName, by: countDigits(rightSeed) + 2)
        let inner = leftSeed + payload + certPart + packagePart + rightSeed
        return shiftDigitsDown(base64NoWrap(inner), by: outerDigitShift) + String(outerDigitShift) + randomAlnum(7)
    }

    private func randomAlnum(_ length: Int) -> String {
        randomChars(length, from: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    }

    private func randomChars(_ length: Int, from allowed: String) -> String {
        let chars = Array(allowed)
        return String((0..<length).map { _ in String(chars.randomElement()!) }.joined())
    }

    private func reverse(_ text: String) -> String {
        String(text.reversed())
    }

    private func insertNoiseAfterEveryChar(_ text: String, allowed: String) -> String {
        var result = ""
        for character in text {
            result.append(character)
            result += randomChars(1, from: allowed)
        }
        return result
    }

    private func caesarLetters(_ text: String, by shift: Int) -> String {
        let shift = shift % 26
        var result = ""
        for scalar in text.unicodeScalars {
            let value = Int(scalar.value)
            if value >= 65 && value <= 90 {
                result.unicodeScalars.append(UnicodeScalar(((value - 65 + shift) % 26) + 65)!)
            } else if value >= 97 && value <= 122 {
                result.unicodeScalars.append(UnicodeScalar(((value - 97 + shift) % 26) + 97)!)
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    private func shiftDigitsDown(_ text: String, by shift: Int) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            var value = Int(scalar.value)
            if value >= 48 && value <= 57 {
                value -= shift
                if value < 48 { value += 10 }
                result.unicodeScalars.append(UnicodeScalar(value)!)
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    private func countDigits(_ text: String) -> Int {
        text.unicodeScalars.filter { $0.value >= 48 && $0.value <= 57 }.count
    }

    private func base64NoWrap(_ text: String) -> String {
        Data(text.utf8).base64EncodedString()
    }
}
