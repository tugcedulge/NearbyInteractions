//
//  MPCSession.swift
//  MultiSimulatorsBuild
//
//  Created by Tuğçe Dülge on 15.12.2020.
//

import simd

// Converts degrees to radians, and back.
extension FloatingPoint {
    var degreesToRadians: Self { self * .pi / 180 }
    var radiansToDegrees: Self { self * 180 / .pi }
}
