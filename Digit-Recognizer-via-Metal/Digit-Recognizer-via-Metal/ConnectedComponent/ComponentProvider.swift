//
//  ComponentProvider.swift
//  Digit-Recognizer-via-Metal
//
//  Created by Andrey Morozov on 10.03.2018.
//  Copyright © 2018 Jastic7. All rights reserved.
//

import Foundation
import CoreGraphics

class ComponentProvider {
    private let width: Int
    private let height: Int
    private let data: [UInt8]
    private var componentMap: [[Int]]
    private var currentComponent = 0
    private var isFound = false
    
    init(imageData data: [UInt8], size: (width: Int, height: Int)) {
        self.height = size.height
        self.width = size.width
        self.data = data
        let componentRow = [Int](repeating: -1, count: width)
        componentMap = [[Int]](repeating: componentRow, count: height)
    }
    
    func findComponents() -> [CGRect] {
        
        var currentLabel = 0
        var labelsUnion = UnionFind(capacity: height * width)

        var labels = [[Int]].init(repeating: [Int](repeating: -1, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                if data[y*width + x] != 0 { // Not background pixel
                    if x == 0 { // Left no pixel
                        if y == 0 { // Top no pixel
                            labelsUnion.addSetWith(currentLabel)
                            labels[y][x] = currentLabel
                            currentLabel += 1
                        } else if y > 0 { //Top pixel
                            if data[(y - 1)*width + x] != 0 { //Top Label
                                labels[y][x] = labels[y - 1][x]
                            } else { //Top no Label
                                labelsUnion.addSetWith(currentLabel)
                                labels[y][x] = currentLabel
                                currentLabel += 1
                            }
                        }
                    } else { //Left pixel
                        if y == 0 { //Top no pixel
                            if data[y*width + x - 1] != 0 { //Left Label
                                labels[y][x] = labels[y][x - 1]
                            } else { //Left no Label
                                labelsUnion.addSetWith(currentLabel)
                                labels[y][x] = currentLabel
                                currentLabel += 1
                            }
                        } else if y > 0 { //Top pixel
                            if data[y * width + x - 1] != 0 { //Left Label
                                if data[(y - 1)*width + x] != 0 { //Top Label
                                    labelsUnion.unionSetsContaining(labels[y - 1][x], and: labels[y][x - 1])

                                    labels[y][x] = labels[y - 1][x]
                                } else { //Top no Label
                                    labels[y][x] = labels[y][x - 1]
                                }
                            } else { //Left no Label
                                if data[(y - 1)*width + x] != 0 { //Top Label
                                    labels[y][x] = labels[y - 1][x]
                                } else { //Top no Label
                                    labelsUnion.addSetWith(currentLabel)
                                    labels[y][x] = currentLabel
                                    currentLabel += 1
                                }
                            }
                        }
                    }
                }
            }
        }
        // Second pass
        for y in 0..<height {
            for x in 0..<width {

                if data[y*width + x] != 0 {
                    labels[y][x] = labelsUnion.setByIndex(labels[y][x])
                }
            }
        }
        

        let componentRects = findBorderPoints(componentMap: labels)
        return createRectangles(from: componentRects)
    }
    
    private func isBackgroundPoint(_ x: Int, _ y: Int) -> Bool {
        return data[y * width + x] == 0 //black color is background
    }
    
    private func isOutsidePoint(_ x: Int, _ y: Int) -> Bool {
        return x >= width || x < 0 || y >= height || y < 0
    }
    
    private func isCheckedPoint(_ x: Int, _ y: Int) -> Bool {
        return componentMap[y][x] != -1
    }
    
    private func isBoundaryPoint(_ x: Int, _ y: Int) -> Bool {
        return x <= 5 || width - x <= 5 || y <= 5 || height - y <= 5
    }
    
    func findBorderPoints(componentMap: [[Int]]) -> [Int : ComponentRect] {
        var componentRects = [Int : ComponentRect]()
        
        for y in 0..<height {
            for x in 0..<width {
                guard componentMap[y][x] != -1 else { continue }
                
                let component = componentMap[y][x]
                
                guard var componentRect = componentRects[component] else {
                    componentRects[component] = ComponentRect(minX: x, minY: y, maxX: x, maxY: y)
                    continue
                }
                
                componentRect.updateCoordinatesByPoint(x, y)
                componentRects[component] = componentRect
            }
        }
        
        return componentRects
    }
    
    func createRectangles(from componentRects: [Int : ComponentRect]) -> [CGRect] {
        var rectangles = [CGRect]()
        
        for (_, rect) in componentRects {
            if isBoundaryPoint(rect.minX, rect.minY) || isBoundaryPoint(rect.maxX, rect.maxY){ continue }
            
            let x = rect.minX
            let y = rect.minY
            let width = rect.maxX - rect.minX
            let height = rect.maxY - rect.minY
            
            if width * height < 50 { continue }
            
            let rectangle = CGRect(x: x, y: y, width: width, height: height)
            
            rectangles.append(rectangle)
        }
        
        return rectangles
    }
}

struct ComponentRect {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int
    
    mutating func updateCoordinatesByPoint(_ x: Int, _ y: Int) {
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x)
        maxY = max(maxY, y)
    }
}
