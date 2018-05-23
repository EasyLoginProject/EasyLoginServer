//
//  DatabaseInfo.swift
//  Application
//
//  Created by Frank on 20/04/2018.
//

import Foundation

struct MigrationInfo: Codable {
    var uuid: String
    var date: Date
}

struct DatabaseInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case revision = "_rev"
        case migrations
    }
    
    var revision: String?
    var migrations: [MigrationInfo]
    
    init() {
        migrations = []
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        revision = try container.decode(String?.self, forKey: .revision)
        migrations = try container.decode([MigrationInfo].self, forKey: .migrations)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(migrations, forKey: .migrations)
    }
    
    mutating func addMigration(uuid: String, date: Date) {
        let migrationInfo = MigrationInfo(uuid: uuid, date: date)
        migrations.append(migrationInfo)
    }
}
