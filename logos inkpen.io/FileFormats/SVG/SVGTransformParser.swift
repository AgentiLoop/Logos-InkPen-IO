import SwiftUI

extension SVGParser {

    func parseTransform(_ transformString: String) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        guard let transformRegex = try? NSRegularExpression(pattern: "(\\w+)\\s*\\(([^)]*)\\)", options: []) else {
            return CGAffineTransform.identity
        }
        let matches = transformRegex.matches(in: transformString, options: [], range: NSRange(location: 0, length: transformString.count))
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let transformType = (transformString as NSString).substring(with: match.range(at: 1))
            let paramsString = (transformString as NSString).substring(with: match.range(at: 2))
            let params = paramsString
                .replacingOccurrences(of: ",", with: " ")
                .split(separator: " ")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            switch transformType.lowercased() {
            case "translate":
                if params.count >= 2 {
                    transform = transform.translatedBy(x: params[0], y: params[1])
                } else if params.count == 1 {
                    transform = transform.translatedBy(x: params[0], y: 0)
                }
            case "scale":
                if params.count >= 2 {
                    transform = transform.scaledBy(x: params[0], y: params[1])
                } else if params.count == 1 {
                    transform = transform.scaledBy(x: params[0], y: params[0])
                }
            case "rotate":
                if params.count >= 3 {
                    let angle = degreesToRadians(params[0])
                    let cx = params[1]
                    let cy = params[2]
                    transform = transform.translatedBy(x: cx, y: cy)
                    transform = transform.rotated(by: angle)
                    transform = transform.translatedBy(x: -cx, y: -cy)
                } else if params.count >= 1 {
                    let angle = degreesToRadians(params[0])
                    transform = transform.rotated(by: angle)
                }
            case "skewx":
                if params.count >= 1 {
                    let angle = degreesToRadians(params[0])
                    transform = CGAffineTransform(a: transform.a, b: transform.b,
                                                 c: transform.c + transform.a * tan(angle),
                                                 d: transform.d + transform.b * tan(angle),
                                                 tx: transform.tx, ty: transform.ty)
                }
            case "skewy":
                if params.count >= 1 {
                    let angle = degreesToRadians(params[0])
                    transform = CGAffineTransform(a: transform.a + transform.c * tan(angle),
                                                 b: transform.b + transform.d * tan(angle),
                                                 c: transform.c, d: transform.d,
                                                 tx: transform.tx, ty: transform.ty)
                }
            case "matrix":
                if params.count >= 6 {
                    let newTransform = CGAffineTransform(a: params[0], b: params[1],
                                                        c: params[2], d: params[3],
                                                        tx: params[4], ty: params[5])
                    transform = transform.concatenating(newTransform)
                }
            default:
                break
            }
        }
        return transform
    }
}
