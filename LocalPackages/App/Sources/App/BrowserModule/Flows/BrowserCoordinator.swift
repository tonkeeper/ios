import UIKit
import TKCoordinator
import TKUIKit
import TKScreenKit
import TKCore
import KeeperCore
import TonSwift
import TKLocalize

public final class BrowserCoordinator: RouterCoordinator<NavigationControllerRouter> {
  
  private let coreAssembly: TKCore.CoreAssembly
  private let keeperCoreMainAssembly: KeeperCore.MainAssembly
  
  public init(router: NavigationControllerRouter,
              coreAssembly: TKCore.CoreAssembly,
              keeperCoreMainAssembly: KeeperCore.MainAssembly) {
    self.coreAssembly = coreAssembly
    self.keeperCoreMainAssembly = keeperCoreMainAssembly
    super.init(router: router)
    router.rootViewController.tabBarItem.title = TKLocales.Tabs.browser
    router.rootViewController.tabBarItem.image = .TKUIKit.Icons.Size28.explore
  }
  
  public override func start() {
    openBrowser()
  }
}

private extension BrowserCoordinator {
  func openBrowser() {
    let module = BrowserAssembly.module(keeperCoreAssembly: keeperCoreMainAssembly)
    
    module.output.didTapSearch = { [weak self] in
      self?.openSearch()
    }
    
    module.output.didSelectCategory = { [weak self] category in
      self?.openCategory(category)
    }
    
    module.output.didSelectApp = { [weak self] app in
      self?.openApp(app)
    }
    
    router.push(viewController: module.view, animated: false)
  }
  
  func openCategory(_ category: PopularAppsCategory) {
    let module = BrowserCategoryAssembly.module(category: category)
    
    module.output.didSelectApp = { [weak self] app in
      self?.openApp(app)
    }
    
    module.view.setupBackButton()
    
    router.push(viewController: module.view)
  }
  
  func openApp(_ app: PopularApp) {
    guard let url = app.url else { return }
    
    let webViewController = TKBridgeWebViewController(initialURL: url, initialTitle: app.name)
    webViewController.addBridgeMessageObserver(message: "blabla") { body in
      print(body)
    }
    webViewController.didLoadInitialURLHandler = {
      Task {
        do {
          try await webViewController.evaulateJavaScript(javaScriptIbj)
          print("OK")
        } catch {
          print(error)
        }
      }
    }
    let nc = TKNavigationController(rootViewController: webViewController)
    nc.modalPresentationStyle = .fullScreen
    router.present(nc)
  }
  
  func openSearch() {
    
  }
}

let javaScriptIbj = """
        (() => {
                        if (!window.tonkeeper) {
                            window.rnPromises = {};
                            window.rnEventListeners = [];
                            window.invokeRnFunc = (name, args, resolve, reject) => {
                                const invocationId = btoa(Math.random()).substring(0, 12);
                                const timeoutMs = null;
                                const timeoutId = timeoutMs ? setTimeout(() => reject(new Error('bridge timeout for function with name: '+name+'')), timeoutMs) : null;
                                window.rnPromises[invocationId] = { resolve, reject, timeoutId }
                                                                window.webkit.messageHandlers.blabla.postMessage(JSON.stringify({
                                    type: 'invokeRnFunc',
                                    invocationId: invocationId,
                                    name,
                                    args,
                                }));
                            };
                            
                            window.addEventListener('message', ({ data }) => {
                                try {
                                    const message = data;
                                    console.log('message bridge', JSON.stringify(message));
                                    if (message.type === 'functionResponse') {
                                        const promise = window.rnPromises[message.invocationId];
                                        
                                        if (!promise) {
                                            return;
                                        }
                                        
                                        if (promise.timeoutId) {
                                            clearTimeout(promise.timeoutId);
                                        }
                                        
                                        if (message.status === 'fulfilled') {
                                            promise.resolve(JSON.parse(message.data));
                                        } else {
                                            promise.reject(new Error(message.data));
                                        }
                                        
                                        delete window.rnPromises[message.invocationId];
                                    }
                                    
                                    if (message.type === 'event') {
                                        window.rnEventListeners.forEach((listener) => listener(message.event));
                                    }
                                } catch { }
                            });
                        }
                        
                        const listen = (cb) => {
                            window.rnEventListeners.push(cb);
                            return () => {
                                const index = window.rnEventListeners.indexOf(cb);
                                if (index > -1) {
                                    window.rnEventListeners.splice(index, 1);
                                }
                            };
                        };
                        
                        window.tonkeeper = {
                            tonconnect: Object.assign({"isWalletBrowser":true,"deviceInfo":{"platform":"ios_x","appName":"Tonkeeper","appVersion":"3.4.0","maxProtocolVersion":2,"features":["SendTransaction"]},"protocolVersion":2},{ send: (...args) => {return new Promise((resolve, reject) => window.invokeRnFunc('send', args, resolve, reject))},connect: (...args) => {return new Promise((resolve, reject) => window.invokeRnFunc('connect', args, resolve, reject))},restoreConnection: (...args) => {return new Promise((resolve, reject) => window.invokeRnFunc('restoreConnection', args, resolve, reject))},disconnect: (...args) => {return new Promise((resolve, reject) => window.invokeRnFunc('disconnect', args, resolve, reject))} },{ listen }),
                        }
                    })();
"""



