/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app's main view.
*/

import SwiftUI
import CoreLocation

let monitorName = "SampleMonitor"
let appleParkLocation = CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090)
let testBeaconId = UUID(uuidString: "A2C56DB5-DFFB-48D2-B060-D0F5A71096E0")!

@MainActor
public class ObservableMonitorModel: ObservableObject {
    
    private let manager: CLLocationManager
    
    // The model doesn't read the published variables. The system only writes them to drive the UI.
    // The CLMonitor state is the only source of truth.
    public var monitor: CLMonitor?
    @Published var UIRows: [String: [CLMonitor.Event]] = [:]
    
    init() {
        self.manager = CLLocationManager()
        self.manager.requestWhenInUseAuthorization()
    }
    
    func startMonitoringConditions() {
        Task {
            monitor = await CLMonitor(monitorName)
            await monitor!.add(getCircularGeographicCondition(), identifier: "ApplePark")
            await monitor!.add(getBeaconIdentityCondition(), identifier: "TestBeacon")
            for identifier in await monitor!.identifiers {
                guard let lastEvent = await monitor!.record(for: identifier)?.lastEvent else { continue }
                UIRows[identifier] = [lastEvent]
            }
            for try await event in await monitor!.events {
                UIRows[event.identifier] = [event]
                
                // While handling the most recent event, the last event is still updating
                // and shows the prior state, allowing you to reference both.
                guard let lastEvent = await monitor!.record(for: event.identifier)?.lastEvent else { continue }
                UIRows[event.identifier]?.append(lastEvent)
            }
        }
    }
    
    func updateRecords() async {
        UIRows = [:]
        for identifier in await monitor?.identifiers ?? [] {
            guard let lastEvent = await monitor!.record(for: identifier)?.lastEvent else { continue }
            UIRows[identifier] = [lastEvent]
        }
    }
}

struct ContentView: View {
    @ObservedObject fileprivate var locationMonitor = ObservableMonitorModel()
    
    var body: some View {
        VStack {
            ScrollView {
                VStack {
                    ForEach(locationMonitor.UIRows.keys.sorted(), id: \.self) {condition in
                        HStack(alignment: .top) {
                            Button(action: {
                                Task {
                                    await locationMonitor.monitor?.remove(condition)
                                    await locationMonitor.updateRecords()
                                }
                            }) {
                                Image(systemName: "xmark.circle")
                            }
                            Text(condition)
                            ScrollViewReader {reader in
                                ScrollView {
                                    VStack {
                                        ForEach((locationMonitor.UIRows[condition] ?? []).indices, id: \.self) {index in
                                            HStack {
                                                switch locationMonitor.UIRows[condition]![index].state {
                                                case .satisfied: Text("Satisfied")
                                                case .unsatisfied: Text("Unsatisfied")
                                                case .unknown: Text("Unknown")
                                                }
                                                Text(locationMonitor.UIRows[condition]![index].date, style: .time)
                                            }
                                        }
                                        Text("")
                                            .frame(height: 5)
                                            .id("lastElement")
                                    }
                                }
                                .frame(height: 40)
                                .onChange(of: locationMonitor.UIRows[condition]!.count) {
                                    reader.scrollTo("lastElement")
                                    Task {
                                        sleep(1)
                                        withAnimation(.easeInOut(duration: 3)) {
                                            reader.scrollTo(0)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }.task {
                locationMonitor.startMonitoringConditions()
            }
        }
        Button("Add CircularGeographicCondition") {
            Task {
                await locationMonitor.monitor?.add(getCircularGeographicCondition(), identifier: "ApplePark")
                await locationMonitor.updateRecords()
            }
        }
        .padding(20)
        .border(.gray)
        .cornerRadius(20)
        Button("Add BeaconIdentityCondition") {
            Task {
                await locationMonitor.monitor?.add(getBeaconIdentityCondition(), identifier: "TestBeacon")
                await locationMonitor.updateRecords()
            }
        }
        .padding(20)
        .border(.gray)
        .cornerRadius(20)
    }
}

func getCircularGeographicCondition() -> CLMonitor.CircularGeographicCondition {
    return CLMonitor.CircularGeographicCondition(
        center: appleParkLocation,
        radius: 50)
}

func getBeaconIdentityCondition() -> CLMonitor.BeaconIdentityCondition {
    CLMonitor.BeaconIdentityCondition(uuid: testBeaconId)
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
