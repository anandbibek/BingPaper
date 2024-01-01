//
//  BingPictureManager.swift
//  BingPaper
//
//  Created by Jingwen Peng on 2015-07-12.
//  Copyright (c) 2015 Jingwen Peng. All rights reserved.
//

import Cocoa

enum DataError: Error {
    case invalidURL
    case invalidData
    case invalidResponse
    case message(_ error: Error?)
}

class BingPictureManager {
    let netRequest = NSMutableURLRequest()
    let fileManager = FileManager.default
    
    var pastWallpapersRange = 8
    
    init() {
        netRequest.cachePolicy = NSURLRequest.CachePolicy.useProtocolCachePolicy
        netRequest.timeoutInterval = 15
        netRequest.httpMethod = "GET"
    }
    
    fileprivate func buildInfoPath(workDir: String, onDate: String, atRegion: String) -> String {
        if atRegion == "" {
            return "\(workDir)/\(onDate).json"
        }
        return "\(workDir)/\(onDate)_\(atRegion).json"
    }
    
    fileprivate func buildImagePath(workDir: String, onDate: String, atRegion: String) -> String {
        if atRegion == "" {
            return "\(workDir)/\(onDate).jpg"
        }
        return "\(workDir)/\(onDate)_\(atRegion).jpg"
    }
    
    fileprivate func checkAndCreateWorkDirectory(workDir: String) {
        try? fileManager.createDirectory(atPath: workDir, withIntermediateDirectories: true, attributes: nil)
    }
    
    fileprivate func obtainWallpaper(workDir: String, atIndex: Int, atRegion: String) {
        let baseURL = "https://www.bing.com/HpImageArchive.aspx"
        let jsonUrl = "\(baseURL)?format=js&n=1&idx=\(atIndex)&cc=\(atRegion)"
        fetchData(url: jsonUrl, completion: { [self]
            result in
            switch result {
                
            case .failure(let error):
                print(error)
                
            case .success(let dataValue):
                                
                let data = try? JSONSerialization.jsonObject(with: dataValue, options: []) as AnyObject
                if let objects = data?.value(forKey: "images") as? [NSObject] {
                    if let startDateString = objects[0].value(forKey: "startdate") as? String,
                       let urlString = objects[0].value(forKey: "urlbase") as? String {
                        
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyyMMdd"
                        if let startDate = formatter.date(from: startDateString) {
                            formatter.dateFormat = "yyyy-MM-dd"
                            let dateString = formatter.string(from: startDate)
                            
                            let infoPath = self.buildInfoPath(workDir: workDir, onDate: dateString, atRegion: atRegion)
                            let imagePath = buildImagePath(workDir: workDir, onDate: dateString, atRegion: atRegion)
                            
                            if !fileManager.fileExists(atPath: infoPath) {
                                checkAndCreateWorkDirectory(workDir: workDir)
                                
                                try? dataValue.write(to: URL(fileURLWithPath: infoPath), options: [.atomic])
                            }
                            
                            if !fileManager.fileExists(atPath: imagePath) {
                                checkAndCreateWorkDirectory(workDir: workDir)
                                
                                let imageUrl = "https://www.bing.com\(urlString)_UHD.jpg"
                                fetchData(url: imageUrl, completion: {
                                    result in
                                    switch result {
                                    case .success(let response):
                                        try? response.write(to: URL(fileURLWithPath: imagePath), options: [.atomic])
                                    case .failure(let error):
                                        print(error)
                                    }
                                })
                            }
                        }
                    }
                }
            }
        })
    }
    
    func fetchData(url: String, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let url = URL(string: url) else {
            completion(.failure(DataError.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data else {
                completion(.failure(DataError.invalidData))
                return
            }
            guard let response = response as? HTTPURLResponse, 200 ... 299  ~= response.statusCode else {
                completion(.failure(DataError.invalidResponse))
                return
            }
            print("Download complete \(url.absoluteString)")
            completion(.success(data))
        }.resume()
    }
    
    func fetchWallpapers(workDir: String, atRegin: String) {
        for index in -1...pastWallpapersRange {
            obtainWallpaper(workDir: workDir, atIndex: index, atRegion: atRegin)
        }
    }
    
    func fetchLastWallpaper(workDir: String, atRegin: String) {
        obtainWallpaper(workDir: workDir, atIndex: 0, atRegion: atRegin)
    }
    
    func checkWallpaperExist(workDir: String, onDate: String, atRegion: String) -> Bool {
        if fileManager.fileExists(atPath: buildImagePath(workDir: workDir, onDate: onDate, atRegion: atRegion)) {
            return true
        }
        return false
    }
    
    func getWallpaperInfo(workDir: String, onDate: String, atRegion: String) -> (copyright: String, copyrightLink: String) {
        let jsonString = try? String.init(contentsOfFile: buildInfoPath(workDir: workDir, onDate: onDate, atRegion: atRegion))
        
        if let jsonData = jsonString?.data(using: String.Encoding.utf8) {
            let data = try? JSONSerialization.jsonObject(with: jsonData, options: []) as AnyObject
            
            if let objects = data?.value(forKey: "images") as? [NSObject] {
                if let copyrightString = objects[0].value(forKey: "copyright") as? String,
                    let copyrightLinkString = objects[0].value(forKey: "copyrightlink") as? String {
                    return (copyrightString, copyrightLinkString)
                }
            }
        }
        
        return ("", "")
    }
    
    func setWallpaper(workDir: String, onDate: String, atRegion: String) {
        if checkWallpaperExist(workDir: workDir, onDate: onDate, atRegion: atRegion) {
            NSScreen.screens.forEach({ (screen) in
                try? NSWorkspace.shared.setDesktopImageURL(
                    URL(fileURLWithPath: buildImagePath(workDir: workDir, onDate: onDate, atRegion: atRegion)),
                    for: screen,
                    options: [:]
                )
            })
        }
    }
}
