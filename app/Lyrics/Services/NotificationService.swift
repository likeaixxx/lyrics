import Cocoa
import UserNotifications
import UserNotificationsUI
import UniformTypeIdentifiers
import CoreServices

final class NotificationService {
    static let shared = NotificationService()

    func requestAuthorization() {
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

    func sendNotification(title: String?, subtitle: String?, body: String?, imageUrlString: String?) {
        downloadImage(from: imageUrlString) { localImageUrl in
            let content = UNMutableNotificationContent()
            content.title = title ?? ""
            content.subtitle = subtitle ?? ""
            content.body = body ?? ""
            content.sound = .default

            if let localImageUrl = localImageUrl {
                do {
                    let attachment = try UNNotificationAttachment(identifier: "imageAttachment", url: localImageUrl, options: nil)
                    content.attachments = [attachment]
                } catch {
                    print("创建附件时出错: \(error)")
                }
            }

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("通知发送失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private func downloadImage(from urlString: String?, completion: @escaping (URL?) -> Void) {
        guard let urlString = urlString, let imageUrl = URL(string: urlString) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: imageUrl)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let mimeType = httpResponse.mimeType,
                  mimeType.hasPrefix("image"),
                  let data = data else {
                completion(nil)
                return
            }

            let fileExtension = self.mimeTypeToExtension(mimeType: mimeType) ?? "tmp"
            let filename = UUID().uuidString + "." + fileExtension
            let tempDirectory = FileManager.default.temporaryDirectory
            let targetURL = tempDirectory.appendingPathComponent(filename)
            do {
                try data.write(to: targetURL)
                completion(targetURL)
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }

    private func mimeTypeToExtension(mimeType: String) -> String? {
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
}
