//
//  SensorApp.swift
//  Sensor
//
//  Created by Domenico Blanco on 02/04/23.
//

import SwiftUI
import CoreMotion
import CocoaMQTT

@main
struct SensorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class MQTTClient {
    private let mqtt: CocoaMQTT5
    private let publishProperties: MqttPublishProperties
        
    init() {
        let connectProperties = MqttConnectProperties()
        publishProperties = MqttPublishProperties()
        
        mqtt = CocoaMQTT5(clientID: MQTTCredentials.CLIENT_ID, host: MQTTCredentials.SERVER, port: MQTTCredentials.PORT)
        publishProperties.contentType = "text"
        connectProperties.topicAliasMaximum = 0
        connectProperties.sessionExpiryInterval = 0
        connectProperties.receiveMaximum = 100
        connectProperties.maximumPacketSize = 500
        
        mqtt.connectProperties = connectProperties
        mqtt.username = ""
        mqtt.password = ""
        mqtt.keepAlive = 60
        mqtt.enableSSL = true
        mqtt.autoReconnect = true
        _ = mqtt.connect()
    }
    
    func publish_update(pressure: String) {
        if (mqtt.connState.rawValue != 0) {
            mqtt.publish(MQTTCredentials.TOPIC, withString: pressure, qos: .qos1, properties: publishProperties)
        }
    }
}

class Sensor: ObservableObject {
    private let altimeter = CMAltimeter()
    private let AmbientPressure = CMAmbientPressureData()
    private let mqtt = MQTTClient()
    private let mqttDelay: TimeInterval
    private let telegramDelay: TimeInterval
    private let telegramEndpoint: String
    private let enabledTechnologies = [!MQTTCredentials.SERVER.isEmpty, !TelegramData.BOT_TOKEN.isEmpty]
    
    private var lastMessage: [Date]
    @Published var pressure: String
    
    init() {
        lastMessage = [Date(), Date()]
        pressure = "0"
        mqttDelay = TimeInterval(60.0)
        telegramDelay = TimeInterval(30.0 * 60.0)
        telegramEndpoint = "https://api.telegram.org/bot\(TelegramData.BOT_TOKEN)/sendMessage?chat_id=\(TelegramData.CHAT_ID)&message_thread_id=\(TelegramData.THREAD_ID)&text="
        
        altimeter.startRelativeAltitudeUpdates(to: OperationQueue.current!, withHandler: set_pressure)
    }
    
    private func set_pressure(data: CMAltitudeData?, error: Error?) {
        if (error != nil) {
            print(error ?? "")
        } else if (error == nil && Date() > lastMessage[0]) {
            let bar = data?.pressure as! Double * 10.0
            lastMessage[0] = Date().addingTimeInterval(mqttDelay)
            
            pressure = String(format: "%.2f", bar)
            
            if (enabledTechnologies[0]) {
                mqtt.publish_update(pressure: pressure)
            }
            if (enabledTechnologies[1]) {
                send_to_telegram()
            }
        }
    }
    
    private func send_to_telegram() {
        let msg = "Pressione: \(pressure) hPa".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Invalid%20msg"
        
        if (Date() > lastMessage[1]) {
            lastMessage[1] = Date().addingTimeInterval(telegramDelay)
            
            let request = URLRequest(url: URL(string: telegramEndpoint+msg)!,timeoutInterval: Double.infinity)

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard data != nil else {
                print(String(describing: error))
                return
              }
            }
            
            task.resume()
        }
    }
}
