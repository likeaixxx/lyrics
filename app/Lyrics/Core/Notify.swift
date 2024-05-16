//
//  Notify.swift
//  lyrics-v3
//
//  Created by 陈爱全 on 2024/5/16.
//

import Foundation
import UserNotifications

func required() {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
        if settings.authorizationStatus == .authorized {
           return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("通知权限已授权")
            } else if let error = error {
                print("请求通知权限出错: \(error)")
            }
        }
    }
}

func sendNotification(title: String?, subtitle: String?, body: String?) {
    let content = UNMutableNotificationContent()
    content.title = title ?? ""
    content.subtitle = subtitle ?? ""
    content.body = body ?? ""
    content.sound = UNNotificationSound.default
    // 通知触发器
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    // 创建一个通知请求
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
    // 将请求添加到通知中心
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("通知发送失败: \(error.localizedDescription)")
        }
    }
}
