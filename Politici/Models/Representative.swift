//
//  Representative.swift
//  Politici
//

import Foundation

struct Representative: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let chamber: Chamber
    let districtId: String
    let party: String
    let parliamentaryGroup: String
    let committees: [String]
    let attendanceRate: Double
    let photoName: String
}
