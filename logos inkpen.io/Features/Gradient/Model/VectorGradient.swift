import SwiftUI

enum VectorGradient: Codable, Hashable {
    case linear(LinearGradient)
    case radial(RadialGradient)

    var stops: [GradientStop] {
        switch self {
        case .linear(let gradient):
            return gradient.stops
        case .radial(let gradient):
            return gradient.stops
        }
    }

    var signature: String {

        func stopSig(_ s: GradientStop) -> String {
            switch s.color {
            case .rgb(let rgb):
                return String(format: "p=%.6f,r=%.6f,g=%.6f,b=%.6f,a=%.6f,so=%.6f", s.position, rgb.red, rgb.green, rgb.blue, rgb.alpha, s.opacity)
            case .cmyk(let c):
                return String(format: "p=%.6f,c=%.6f,m=%.6f,y=%.6f,k=%.6f,so=%.6f", s.position, c.cyan, c.magenta, c.yellow, c.black, s.opacity)
            case .hsb(let h):
                return String(format: "p=%.6f,h=%.6f,s=%.6f,b=%.6f,a=%.6f,so=%.6f", s.position, h.hue, h.saturation, h.brightness, h.alpha, s.opacity)
            case .appleSystem(let sys):
                return "p=\(s.position),sys=\(sys.name),so=\(s.opacity)"
            case .pantone(let p):
                return "p=\(s.position),pantone=\(p.pantone),so=\(s.opacity)"
            case .spot(let sp):
                return "p=\(s.position),spot=\(sp.name),so=\(s.opacity)"
            case .black:
                return "p=\(s.position),black,so=\(s.opacity)"
            case .white:
                return "p=\(s.position),white,so=\(s.opacity)"
            case .clear:
                return "p=\(s.position),clear,so=\(s.opacity)"
            case .gradient:
                return "p=\(s.position),gradref,so=\(s.opacity)"
            }
        }
        switch self {
        case .linear(let lg):
            let stopsSig = lg.stops.map(stopSig).joined(separator: "|")
            return String(format: "lin:x1=%.6f,y1=%.6f,x2=%.6f,y2=%.6f,units=%@,spread=%@,ox=%.6f,oy=%.6f,scx=%.6f,scy=%.6f,ang=%.6f::%@",
                          lg.startPoint.x, lg.startPoint.y, lg.endPoint.x, lg.endPoint.y,
                          lg.units.rawValue, lg.spreadMethod.rawValue,
                          lg.originPoint.x, lg.originPoint.y, lg.scaleX, lg.scaleY, lg.storedAngle, stopsSig)
        case .radial(let rg):
            let stopsSig = rg.stops.map(stopSig).joined(separator: "|")
            let fx = rg.focalPoint?.x ?? .nan
            let fy = rg.focalPoint?.y ?? .nan
            return String(format: "rad:cx=%.6f,cy=%.6f,r=%.6f,fx=%.6f,fy=%.6f,units=%@,spread=%@,ox=%.6f,oy=%.6f,scx=%.6f,scy=%.6f,ang=%.6f::%@",
                          rg.centerPoint.x, rg.centerPoint.y, rg.radius, fx, fy,
                          rg.units.rawValue, rg.spreadMethod.rawValue,
                          rg.originPoint.x, rg.originPoint.y, rg.scaleX, rg.scaleY, rg.angle, stopsSig)
        }
    }
}
