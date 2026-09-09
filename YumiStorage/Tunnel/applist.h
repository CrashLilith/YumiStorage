//
//  applist.h
//  YumiStorage
//
//  InstallationProxy / SpringBoard helpers over an RPPairing RSD tunnel.
//

#ifndef APPLIST_H
#define APPLIST_H
@import Foundation;
@import UIKit;
#include "idevice.h"

NSDictionary<NSString*, NSString*>* list_installed_apps(struct AdapterHandle *adapter, struct RsdHandshakeHandle *handshake, NSString** error);
NSDictionary<NSString*, NSString*>* list_all_apps(struct AdapterHandle *adapter, struct RsdHandshakeHandle *handshake, NSString** error);
NSDictionary<NSString*, NSString*>* list_hidden_system_apps(struct AdapterHandle *adapter, struct RsdHandshakeHandle *handshake, NSString** error);
UIImage* getAppIcon(struct AdapterHandle *adapter, struct RsdHandshakeHandle *handshake, NSString* bundleID, NSString** error);

NSDictionary *getAllAppsInfo(struct AdapterHandle *adapter, struct RsdHandshakeHandle *handshake, NSString **error);
NSDictionary *getAllAppsInfoFromProvider(struct IdeviceProviderHandle *provider, NSString **error);
UIImage *getAppIconFromProvider(struct IdeviceProviderHandle *provider, NSString *bundleID, NSString **error);
id plist_to_objc_object(plist_t plist);

#endif /* APPLIST_H */
