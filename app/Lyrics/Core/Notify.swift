//
//  Notify.swift
//  lyrics-v3
//
//  Created by likeai on 2024/5/16.
//
import Cocoa
import UserNotifications
import UserNotificationsUI
import UniformTypeIdentifiers
import CoreServices

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

func downloadImage(from urlString: String?, completion: @escaping (URL?) -> Void) {
    guard let urlString = urlString, let imageUrl = URL(string: urlString) else {
        completion(nil)
        return
    }

    // 创建请求并设置 User-Agent
    var request = URLRequest(url: imageUrl)
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

    // 使用 dataTask 下载数据
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard error == nil else {
            print("下载图片失败: \(error!.localizedDescription)")
            completion(nil)
            return
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let mimeType = httpResponse.mimeType,
              mimeType.hasPrefix("image"),
              let data = data else {
            print("下载图片失败: 无效的响应")
            completion(nil)
            return
        }

        // 获取文件扩展名
        let fileExtension = mimeTypeToExtension(mimeType: mimeType) ?? "tmp"
        // 为文件生成唯一的名称
        let filename = UUID().uuidString + "." + fileExtension
        // 获取 App Group 的共享容器 URL
        let tempDirectory = FileManager.default.temporaryDirectory
        let targetURL = tempDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: targetURL)
            completion(targetURL)
        } catch {
            print("保存图片时出错: \(error)")
            completion(nil)
        }
    }
    task.resume()
}

// 辅助函数：将 MIME 类型映射到文件扩展名
func mimeTypeToExtension(mimeType: String) -> String? {
    if #available(macOS 11.0, *) {
        if let uti = UTType(mimeType: mimeType),
           let fileExtension = uti.preferredFilenameExtension {
            return fileExtension
        }
    } else {
        let cfMimeType = mimeType as CFString
        if let unmanagedUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, cfMimeType, nil),
           let uti = unmanagedUTI.takeRetainedValue() as String?,
           let unmanagedExt = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassFilenameExtension),
           let fileExtension = unmanagedExt.takeRetainedValue() as String? {
            return fileExtension
        }
    }
    return nil
}

func sendNotification(title: String?, subtitle: String?, body: String?, imageUrlString: String?) {
    downloadImage(from: imageUrlString) { localImageUrl in
        let content = UNMutableNotificationContent()
        content.title = title ?? ""
        content.subtitle = subtitle ?? ""
        content.body = body ?? ""
        content.sound = .default

        // 创建图片附件（如果有）
        if let localImageUrl = localImageUrl {
            do {
                let attachment = try UNNotificationAttachment(identifier: "imageAttachment", url: localImageUrl, options: nil)
                content.attachments = [attachment]
            } catch {
                print("创建附件时出错: \(error)")
            }
        }

        // 通知触发器
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        // 创建通知请求
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        // 将请求添加到通知中心
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("通知发送失败: \(error.localizedDescription)")
            }
        }
    }
}

class NotificationViewController: NSViewController, UNNotificationContentExtension {

    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var bodyLabel: NSTextField!
    @IBOutlet weak var attachmentImageView: NSImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // 初始化代码
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        titleLabel.stringValue = content.title
        bodyLabel.stringValue = content.body

        if let attachment = content.attachments.first {
            if attachment.url.startAccessingSecurityScopedResource() {
                defer { attachment.url.stopAccessingSecurityScopedResource() }
                if let imageData = try? Data(contentsOf: attachment.url) {
                    attachmentImageView.image = NSImage(data: imageData)
                } else {
                    print("无法读取附件数据")
                }
            } else {
                print("无法访问附件的安全范围资源")
            }
        }
    }
}
