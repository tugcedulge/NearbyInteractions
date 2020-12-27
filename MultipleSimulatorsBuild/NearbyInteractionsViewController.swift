//
//  NearbyInteractionsViewController.swift
//  MultiSimulatorsBuild
//
//  Created by Tuğçe Dülge on 15.12.2020.
//

import UIKit
import NearbyInteraction
import MultipeerConnectivity

class NearbyInteractionsViewController: UIViewController, NISessionDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var viewContainer: UIView!
    @IBOutlet weak var labelSnowman: UILabel!
    @IBOutlet weak var labelSnowFlake: UILabel!
    @IBOutlet weak var labelDistance: UILabel!
    @IBOutlet weak var viewSnow: UIStackView!
    
    // MARK: - Distance and direction state
    let nearbyDistanceThreshold: Float = 0.3 // meters
    enum DistanceDirectionState {
        case closeUpInFOV, notCloseUpInFOV, outOfFOV, unknown
    }
    
    // MARK: - Class variables
    var session: NISession?
    var peerDiscoveryToken: NIDiscoveryToken?
    var mpc: MPCSession?
    var connectedPeer: MCPeerID?
    var currentDistanceDirectionState: DistanceDirectionState = .unknown
    var sharedTokenWithPeer = false
    
    // MARK: - UI LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("jdlkbdzlkbl")
        initView()
        start()
    }
    
     private func initView(){
        labelSnowman.text = "☃️"
        labelSnowman.font = UIFont.systemFont(ofSize: 100)
        labelSnowFlake.text = "❄️"
        labelSnowFlake.font = UIFont.systemFont(ofSize: 100)
    }
    
     private func start() {
        session = NISession()
        session?.delegate = self
        sharedTokenWithPeer = false
        
        if connectedPeer != nil && mpc != nil {
            if let myToken = session?.discoveryToken {
                if !sharedTokenWithPeer {
                    shareMyDiscoveryToken(token: myToken)
                }
            } else {
                fatalError("Unable to get self discovery token, is this session invalidated?")
            }
        } else {
            startupMPC()
        }
    }
    
    // MARK: - Sharing and receiving discovery token via mpc mechanics
    private func startupMPC() {
        if mpc == nil {
            mpc = MPCSession(service: "tugcedulge", identity: "identifier", maxPeers: 1)
            mpc?.peerConnectedHandler = connectedToPeer
            mpc?.peerDataHandler = dataReceivedHandler
            mpc?.peerDisconnectedHandler = disconnectedFromPeer
        }
        mpc?.invalidate()
        mpc?.start()
    }
    
    private func shareMyDiscoveryToken(token: NIDiscoveryToken) {
        guard let encodedData = try?  NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
            fatalError("Unexpectedly failed to encode discovery token.")
        }
        mpc?.sendDataToAllPeers(data: encodedData)
        sharedTokenWithPeer = true
    }
    
    private func connectedToPeer(peer: MCPeerID) {
        guard let myToken = session?.discoveryToken else {
            fatalError("Unexpectedly failed to initialize nearby interaction session.")
        }

        if connectedPeer != nil {
            fatalError("Already connected to a peer.")
        }

        if !sharedTokenWithPeer {
            shareMyDiscoveryToken(token: myToken)
        }

        connectedPeer = peer
    }

    private func disconnectedFromPeer(peer: MCPeerID) {
        if connectedPeer == peer {
            connectedPeer = nil
            sharedTokenWithPeer = false
        }
    }

    private func dataReceivedHandler(data: Data, peer: MCPeerID) {
        guard let discoveryToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
            fatalError("Unexpectedly failed to decode discovery token.")
        }
        peerDidShareDiscoveryToken(peer: peer, token: discoveryToken)
    }
    
    private func peerDidShareDiscoveryToken(peer: MCPeerID, token: NIDiscoveryToken) {
        if connectedPeer != peer {
            fatalError("Received token from unexpected peer.")
        }
        peerDiscoveryToken = token
        let config = NINearbyPeerConfiguration(peerToken: token)
        session?.run(config)
    }
    
    private func updateVisualization(from currentState: DistanceDirectionState, to nextState: DistanceDirectionState, with peer: NINearbyObject) {
        UIView.animate(withDuration: 0.3, animations: {
            self.animate(from: currentState, to: nextState, with: peer)
        })
    }
    
    func animate(from currentState: DistanceDirectionState, to nextState: DistanceDirectionState, with peer: NINearbyObject) {

        let size = viewSnow.frame.size
        let containerWidth = viewContainer.frame.width
        let containerHeight = viewContainer.frame.height
        let point = Point(distance: peer.distance, direction: peer.direction)
        
        if let azimuth = point.azimuth, let elevation = point.elevation {
            let origin = CGPoint(x: (containerWidth / 2) + CGFloat(azimuth) * (containerWidth / 2),
                                 y: (containerHeight / 2) - CGFloat(elevation) * (containerHeight / 2))
            viewSnow.frame = .init(origin: .init(x: origin.x - size.width/2 , y: origin.y - size.height/2), size: size)
        }
        
        switch nextState {
        case .closeUpInFOV:
            labelSnowman.text = "☃️"
        case .notCloseUpInFOV:
            labelSnowman.text = "⛄️"
        case .outOfFOV:
            labelSnowman.text = "❄️"
        case .unknown:
            labelSnowman.text = ""
        }
        
        if peer.distance != nil {
            labelDistance.text = String(format: "%0.2f m", peer.distance!)
        }
        
        if nextState == .outOfFOV || nextState == .unknown {
            return
        }
    }
    
    // MARK: - Visualizations
    private func isNearby(_ distance: Float) -> Bool {
        return distance < nearbyDistanceThreshold
    }
    
    private func getDistanceDirectionState(from nearbyObject: NINearbyObject) -> DistanceDirectionState {
        if nearbyObject.distance == nil && nearbyObject.direction == nil {
            return .unknown
        }

        let isNearby = nearbyObject.distance.map(isNearby(_:)) ?? false
        let directionAvailable = nearbyObject.direction != nil

        if isNearby && directionAvailable {
            return .closeUpInFOV
        }

        if !isNearby && directionAvailable {
            return .notCloseUpInFOV
        }

        return .outOfFOV
    }
    
    //MARK: - NISessionDelegate
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let peerToken = peerDiscoveryToken else {
            fatalError("don't have peer token")
        }

        let peerObj = nearbyObjects.first { (obj) -> Bool in
            return obj.discoveryToken == peerToken
        }

        guard let nearbyObjectUpdate = peerObj else {
            return
        }

        let nextState = getDistanceDirectionState(from: nearbyObjectUpdate)
        updateVisualization(from: currentDistanceDirectionState, to: nextState, with: nearbyObjectUpdate)
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {}
    func sessionWasSuspended(_ session: NISession) {}
    func sessionSuspensionEnded(_ session: NISession) {}
    func session(_ session: NISession, didInvalidateWith error: Error) {}
}

