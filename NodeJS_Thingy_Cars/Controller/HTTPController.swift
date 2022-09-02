//
//  HTTP.swift
//  NodeJS_Thingy_Cars
//
//  Created by Martin Terhes on 7/30/22.
//

import Foundation

struct ReturnCar {
    var cars: [Car] = [Car(license_plate: "ERROR", brand_id: 1, brand: "ERROR", model: "ERROR", codename: "ERROR", year: 9999, comment: "ERROR", is_new: 1)]
    var error: String = "DEFAULT_VALUE"
}

func loadData() async -> ReturnCar {
    let url = getURL(whichUrl: "cars")
    var returnedData = ReturnCar()
    
    do {
        // (data, metadata)-ban metadata most nem kell, ezért lehet _
        let (data, _) = try await URLSession.shared.data(from: url)
//        print(String(data: data, encoding: .utf8))
        
        if (String(data: data, encoding: .utf8)?.contains("502") == true) {
            returnedData.error = "Could not reach API (502)"
            returnedData.cars = [Car(license_plate: "ERROR", brand_id: 1, brand: "ERROR", model: "ERROR", codename: "ERROR", year: 9999, comment: "ERROR", is_new: 1)]
            return returnedData
        }
        return initData(dataCuccli: data)
    } catch {
        print("Invalid data")
        returnedData.error = error.localizedDescription
        returnedData.cars = [Car(license_plate: "ERROR", brand_id: 1, brand: "ERROR", model: "ERROR", codename: "ERROR", year: 9999, comment: "ERROR", is_new: 1)]
        return returnedData
    }
}

func loadCar(license_plate: String) async -> ReturnCar {
    let url = URL(string: getURLasString(whichUrl: "cars") + "/" + license_plate.uppercased())!
//    print(url)
    var returnedData = ReturnCar()
    
    do {
        let (data, _) = try await URLSession.shared.data(from: url)
        
        if (String(data: data, encoding: .utf8)?.contains("502") == true) {
            returnedData.error = "Could not reach API (502)"
            returnedData.cars = [Car(license_plate: "ERROR", brand_id: 1, brand: "ERROR", model: "ERROR", codename: "ERROR", year: 9999, comment: "ERROR", is_new: 1)]
            return returnedData
        }
        
        return initData(dataCuccli: data)
    } catch {
        print("Invalid data")
        returnedData.error = error.localizedDescription
        returnedData.cars = [Car(license_plate: "ERROR", brand_id: 1, brand: "ERROR", model: "ERROR", codename: "ERROR", year: 9999, comment: "ERROR", is_new: 1)]
        return returnedData
    }
}

func saveData(uploadableCarData: CarData, isUpload: Bool, isUpdate: Bool) async -> Bool {
    guard let encoded = try? JSONEncoder().encode(uploadableCarData.car) else {
        print("Failed to encode order")
        return false
    }
    
    var url: URL
    url = isUpload ? getURL(whichUrl: "cars") : URL(string: getURLasString(whichUrl: "cars") + "/" + uploadableCarData.oldLicensePlate.uppercased())!
    
    var request = URLRequest(url: url)
            
    request.httpMethod = isUpload ? "POST" : "PUT"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        let (data, _) = try await URLSession.shared.upload(for: request, from: encoded)
        print(String(data: data, encoding: .utf8))
        return true
    } catch {
        print("Checkout failed.")
        return false
    }
}

func deleteHelper (
    request: inout URLRequest,
    cars: inout [Car],
    returnedData: inout ReturnCar,
    offsets: IndexSet,
    completionHandler: @escaping (_ returnedDataHe: ReturnCar?) -> Void
    ) {
    
    var request = request
    var cars = cars
    var returnedData = returnedData
//    var offsets = offsets
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        print(2)
        guard error == nil else {
            print("Error: error calling DELETE")
            print("deleteData error: \(error)")
            returnedData.error = "Error calling DELETE \n \(error)"
            completionHandler(returnedData)
            return
        }
        guard let data = data else {
            print("Error: Did not receive data")
            returnedData.error = "Did not receive data in deleteData"
            completionHandler(returnedData)
            return
        }
        
        do {
            print(3)
            var decodedData: Response
            decodedData = try JSONDecoder().decode(Response.self, from: data)
            print(decodedData.message as Any)
        } catch {
            print("Error: Trying to convert JSON data to string")
            print("Error during decoding in deleteData. Error: \(error)")
            returnedData.error = "Error during decoding in deleteData \n \(error)"
            returnedData.cars = cars
            completionHandler(returnedData)
            return
        }
        returnedData.cars.remove(atOffsets: offsets)
        completionHandler(returnedData)
        print(4)
    }.resume()
}

func deleteData(at offsets: IndexSet, cars: [Car]) async throws -> ReturnCar {
    
    var cars = cars
    var returnedData = ReturnCar()
    returnedData.cars = cars
    
    let url1 = getURLasString(whichUrl: "cars") + "/" + (cars[offsets.first!].license_plate).uppercased()
    let urlFormatted = URL(string: url1)
    var request = URLRequest(url: urlFormatted!)
    request.httpMethod = "DELETE"
        
    return try await withCheckedThrowingContinuation ({ (continuation: CheckedContinuation) in
        deleteHelper(request: &request, cars: &cars, returnedData: &returnedData, offsets: offsets) { returnedDataHe in
            if let returnedDataHe {
                continuation.resume(returning: returnedDataHe)
            }
        }
    })
}

func initData(dataCuccli: Data) -> ReturnCar {
    var decodedData: Response
    var returnedData = ReturnCar()
    
    do {
        decodedData = try JSONDecoder().decode(Response.self, from: dataCuccli)
            
        if (decodedData.status == "success") {
            print("status (Cars): \(decodedData.status)")
            returnedData.cars = decodedData.cars!
            return returnedData
        } else {
            print("Failed response: \(decodedData.message ?? "No error message from server (?)")")
            returnedData.error = decodedData.message ?? "No error message from server (?)"
            return returnedData
        }

    } catch {
        print("initData error: \(error)")
        returnedData.error = error.localizedDescription
        returnedData.cars = [Car(license_plate: "ERROR", brand_id: 1, brand: "ERROR", model: "ERROR", codename: "ERROR", year: 9999, comment: "ERROR", is_new: 1)]
        return returnedData
    }
}


func loadBrands() async -> [Brand] {
    let url = getURL(whichUrl: "brands")
    
    do {
        // (data, metadata)-ban metadata most nem kell, ezért lehet _
        let (data, _) = try await URLSession.shared.data(from: url)
        
        return initBrand(dataCuccli: data)
    } catch {
        print("Invalid data")
    }
    return [Brand(brand_id: 1, brand: "ERROR")]
}

//func loadBrand(license_plate: String) async -> [Brand] {
//    let url = URL(string: getURLasString(whichUrl: "brands") + "/" + license_plate.uppercased())!
//    print(url)
//
//    do {
//        let (data, _) = try await URLSession.shared.data(from: url)
//
//        return initBrand(dataCuccli: data)
//    } catch {
//        print("Invalid data")
//    }
//    return [Brand(brand_id: 1, brand: "ERROR")]
//}

func initBrand(dataCuccli: Data) -> [Brand] {
    var decodedData: Response
    do {
        decodedData = try JSONDecoder().decode(Response.self, from: dataCuccli)
            
        if (decodedData.status == "success") {
            print("status (Brand): \(decodedData.status)")
            return decodedData.brands!
        } else {
            print("Failed response: \(decodedData.message)")
        }

    } catch {
        print(error)
    }
    return [Brand(brand_id: 1, brand: "ERROR")]
}

