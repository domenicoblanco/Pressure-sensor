//
//  ContentView.swift
//  Sensor
//
//  Created by Domenico Blanco on 02/04/23.
//

import SwiftUI

struct ContentView: View {
  @ObservedObject var data = Sensor()
    
    var body: some View {
        VStack {
            Text("Pressure: \(data.pressure)")
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
