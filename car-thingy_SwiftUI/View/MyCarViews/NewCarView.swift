//
//  NewCar.swift
//  NodeJS_Thingy_Cars
//
//  Created by Martin Terhes on 7/8/22.
//

import SwiftUI
import CoreLocation
#if canImport(CoreLocationUI)
import CoreLocationUI
#endif
import MapKit

enum MapType: String {
    case custom = "customMap"
    case current = "currentMap"
    case existing = "existingMap"
}
enum Field: Int, Hashable {
    case newLicensePlate
}

struct NewCar: View {
    @Environment(\.presentationMode) var presentationMode
    
    @EnvironmentObject var sharedViewData: SharedViewData
    
    @FocusState private var focusedField: Field?
    
    @State private var ezLenniCar: Car = Car()
    @State private var oldLicensePlate = ""
    
    @StateObject var locationManager = LocationManager()
    @State private var customLatitude: String = ""
    @State private var customLongitude: String = ""
    @State private var selectedMap = MapType.custom
    
    private var isUpload: Bool
    
    init(isUpload: Bool, isNewBrand: State<Bool> = State(initialValue: false)) {
        self.isUpload = isUpload
        self._selectedMap = {
            if (isUpload) {
                return State(initialValue: MapType.current)
            } else if (!isUpload) {
                return  State(initialValue: MapType.existing)
            } else {
                return  State(initialValue: MapType.custom)
            }
        }()
    }
    
    let removableCharacters: Set<Character> = ["-"]
    var textBindingLicensePlate: Binding<String> {
            Binding<String>(
                get: {
                    return ezLenniCar.specs.license_plate
                    
            },
                set: { newString in
                    self.ezLenniCar.specs.license_plate = newString.uppercased()
                    self.ezLenniCar.specs.license_plate.removeAll(where: {
                        removableCharacters.contains($0)
                    })
            })
    }
    var textBindingComment: Binding<String> {
            Binding<String>(
                get: {
                    return self.ezLenniCar.specs.comment
            },
                set: { newString in
                    self.ezLenniCar.specs.comment = newString
            })
    }
    
    var body: some View {
        
        NavigationView {
            Form {
                Section {
                    TextField("License Plate", text: textBindingLicensePlate)
                        .focused($focusedField, equals: .newLicensePlate)
                } header: {
                    Text("License Plate")
                }
                
                Section {
                    Picker("Flavor", selection: $selectedMap) {
                        Text("Current Map").tag(MapType.current)
                        Text("Custom Map").tag(MapType.custom)
                        Text("Existing Map").tag(MapType.existing)
                    }
                    .pickerStyle(.segmented)
                    
                    Section {
                        if selectedMap == MapType.custom {
                            TextField("Custom latitude", text: $customLatitude)
                                .keyboardType(.decimalPad)
                            TextField("Custom longitude", text: $customLongitude)
                                .keyboardType(.decimalPad)
                        } else if (selectedMap == MapType.current || isUpload) {
                            Map(
                                coordinateRegion: $locationManager.region,
                                interactionModes: MapInteractionModes.all,
                                showsUserLocation: true,
                                userTrackingMode: .none
                            )
                            .frame(height: 200)
                        } else if (selectedMap == MapType.existing || !isUpload) {
                            Map(
                                coordinateRegion: $sharedViewData.region,
                                interactionModes: MapInteractionModes.all,
                                annotationItems: [ezLenniCar]
                            ) {
                                MapMarker(coordinate: $0.getLocation().center)
                            }
                            .frame(height: 200)
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                
                Section {
                    TextField("Comment", text: textBindingComment)
                } header: {
                    Text("Comment")
                }
            }
            .alert("Error", isPresented: $sharedViewData.showAlert, actions: {
                Button("Got it") {
                    sharedViewData.showAlert = false
                }
            }, message: {
                Text("Could not connect to server!")
            })
            
            // MARK: Toolbar items
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading, content: {
                    close
                })
                ToolbarItemGroup(placement: .navigationBarTrailing, content: {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .isHidden(!sharedViewData.isLoading)
                    
                    save
                        .disabled(sharedViewData.isLoading)
                })
            }
        }
        .onAppear() {
            MyCarsView().haptic(type: .notification)
            if (sharedViewData.isEditCarPresented) {
                self.ezLenniCar = sharedViewData.existingCar
            } else {
                self.ezLenniCar = sharedViewData.newCar
                sharedViewData.is_new = true
                DispatchQueue.main.asyncAfter(deadline: .now() + .microseconds(1)) {
                    focusedField = .newLicensePlate
                }
            }
            oldLicensePlate = sharedViewData.existingCar.specs.license_plate
        }
    }
    
    // MARK: Button functions
    var save: some View {
        Button(action: {
            Task {
                sharedViewData.isLoading = true
                
                if (selectedMap == MapType.custom) {
                    ezLenniCar.general.latitude = Double(customLatitude) ?? 37.789467
                    ezLenniCar.general.longitude = Double(customLongitude) ?? -122.416772
                } else if (selectedMap == MapType.current) {
                    ezLenniCar.general.latitude = locationManager.region.center.latitude
                    ezLenniCar.general.longitude = locationManager.region.center.longitude
                }
                
                oldLicensePlate = oldLicensePlate.uppercased()
                oldLicensePlate.removeAll(where: {
                    removableCharacters.contains($0)
                })
                
                ezLenniCar.general.license_plate = ezLenniCar.specs.license_plate
                
//                var ezLenniCarData = CarData(car: ezLenniCar, oldLicensePlate: ezLenniCar.license_plate)
//                
//                if (oldLicensePlate != ezLenniCar.license_plate) {
//                    ezLenniCarData.oldLicensePlate = oldLicensePlate
//                    sharedViewData.existingCar.license_plate = ezLenniCar.license_plate
//                }
                
                let successfullyUploaded = await saveData(uploadableCarData: ezLenniCar, isUpload: isUpload)
                sharedViewData.isLoading = false
                
                if successfullyUploaded {
                    sharedViewData.isEditCarPresented = false
                    presentationMode.wrappedValue.dismiss()
                    MyCarsView().haptic()
                    print("Success: Upload")
                } else {
                    sharedViewData.error = "Failed: Upload"
                    sharedViewData.showAlert = true
                    MyCarsView().haptic(type: .error)
                    print("Failed: Upload")
                }
                presentationMode.wrappedValue.dismiss()
                
            }
        }, label: {
            Text("Save")
        })
    }
    
    var close: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }, label: {
            Text("Close")
        })
    }
}

struct NewCar_Previews: PreviewProvider {
    static var previews: some View {
        NewCar(isUpload: false)
            .environmentObject(SharedViewData())
    }
}
