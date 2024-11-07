//
//  LocationManager.swift
//  LocationTester
//
//  Created by Mark Tassinari on 10/20/24.
//

import Foundation
import CoreLocation



class Location : NSObject, CLLocationManagerDelegate{
    var locationManager: CLLocationManager
    var status : CLAuthorizationStatus = .notDetermined
    var callback: ((CLLocation) -> Void)?
    var statuscallback: ((CLAuthorizationStatus) -> Void)?
    
    override init() {
        locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    }
    deinit {
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.status = status
        statuscallback?(status)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        callback?(locations.last!)
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        print(error)
    }
    func requestLocation(){
        locationManager.startUpdatingLocation()
        
    }
    func stopLocation(){
        locationManager.stopUpdatingLocation()
        
    }
    
    
}
