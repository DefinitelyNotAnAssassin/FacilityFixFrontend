import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:facilityfix/models/chat_models.dart';
import 'package:facilityfix/services/firebase_config.dart';
import 'package:facilityfix/services/auth_storage.dart';

class FirebaseChatService {
  static final FirebaseChatService _instance = FirebaseChatService._internal();
  factory FirebaseChatService() => _instance;
  FirebaseChatService._internal();

  final FirebaseFirestore _firestore = FirebaseConfig.firestore;
  final Map<String, StreamSubscription> _messageSubscriptions = {};
  final Map<String, StreamSubscription> _roomSubscriptions = {};

  // Generate unique room code
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        8,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  // Create or get existing chat room
  Future<ChatRoom> createOrGetRoom({
    required List<String> participants,
    String? concernSlipId,
    String? maintenanceId,
    String? jobServiceId,
  }) async {
    try {
      // Check Firebase connection first
      await _ensureFirebaseConnection();

      // Check if room already exists for this reference
      Query query = _firestore.collection('rooms');

      if (concernSlipId != null) {
        query = query.where('concern_slip_id', isEqualTo: concernSlipId);
      } else if (maintenanceId != null) {
        query = query.where('maintenance_id', isEqualTo: maintenanceId);
      } else if (jobServiceId != null) {
        query = query.where('job_service_id', isEqualTo: jobServiceId);
      } else {
        // For general rooms, check by participants
        query = query.where('participants', arrayContainsAny: participants);
      }

      final existingRooms = await query.get();

      if (existingRooms.docs.isNotEmpty) {
        final existingRoom = ChatRoom.fromFirestore(existingRooms.docs.first);

        // Add current user to participants if not already present
        final currentUserId = participants.first;
        if (!existingRoom.participants.contains(currentUserId)) {
          await _firestore.collection('rooms').doc(existingRoom.id).update({
            'participants': FieldValue.arrayUnion([currentUserId]),
          });

          // Return updated room
          return ChatRoom(
            id: existingRoom.id,
            participants: [...existingRoom.participants, currentUserId],
            roomCode: existingRoom.roomCode,
            concernSlipId: existingRoom.concernSlipId,
            maintenanceId: existingRoom.maintenanceId,
            jobServiceId: existingRoom.jobServiceId,
            createdAt: existingRoom.createdAt,
            updatedAt: DateTime.now(),
            lastMessage: existingRoom.lastMessage,
          );
        }

        return existingRoom;
      }

      // Create new room
      final roomCode = _generateRoomCode();
      final now = DateTime.now();

      final roomData = ChatRoom(
        id: '', // Will be set by Firestore
        participants: participants,
        roomCode: roomCode,
        concernSlipId: concernSlipId,
        maintenanceId: maintenanceId,
        jobServiceId: jobServiceId,
        createdAt: now,
        updatedAt: now,
      );

      final docRef = await _firestore
          .collection('rooms')
          .add(roomData.toFirestore());

      return ChatRoom(
        id: docRef.id,
        participants: participants,
        roomCode: roomCode,
        concernSlipId: concernSlipId,
        maintenanceId: maintenanceId,
        jobServiceId: jobServiceId,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e) {
      print('Error creating/getting room: $e');
      if (e.toString().contains('Unable to establish connection')) {
        throw Exception(
          'Firebase connection failed. Please check your internet connection and Firebase configuration.',
        );
      }
      rethrow;
    }
  }

  // Check Firebase connection with fallback for offline mode
  Future<void> _ensureFirebaseConnection() async {
    try {
      // Try to perform a simple operation to test connection
      await _firestore
          .collection('_connection_test')
          .limit(1)
          .get()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('Connection timeout'),
          );
    } catch (e) {
      print('Firebase connection test failed: $e');

      // Check if we're in offline mode with persistence enabled
      try {
        final settings = _firestore.settings;
        if (settings.persistenceEnabled == true) {
          print('Firebase persistence is enabled - allowing offline mode');
          return; // Allow offline operations
        }
      } catch (_) {
        // Settings not accessible
      }

      // If we can't connect and no offline support, throw error
      throw Exception(
        'Firebase is not properly configured or connection failed. Please check your internet connection and Firebase setup. Error: $e',
      );
    }
  }

  // Send message
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String message,
    String contentType = 'text',
  }) async {
    try {
      final profile = await AuthStorage.getProfile();
      final userId = profile?['uid'] ?? profile?['user_id'] ?? '';

      if (userId.isEmpty) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now();
      final messageData = ChatMessage(
        id: '', // Will be set by Firestore
        roomId: roomId,
        message: message,
        contentType: contentType,
        sentBy: userId,
        timestamp: now,
      );

      // Add message to subcollection
      final docRef = await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .add(messageData.toFirestore());

      // Update room's last message and timestamp
      await _firestore.collection('rooms').doc(roomId).update({
        'last_message': {
          'id': docRef.id,
          'message': message,
          'sent_by': userId,
          'timestamp': Timestamp.fromDate(now),
          'content_type': contentType,
        },
        'updated_at': Timestamp.fromDate(now),
      });

      return ChatMessage(
        id: docRef.id,
        roomId: roomId,
        message: message,
        contentType: contentType,
        sentBy: userId,
        timestamp: now,
      );
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Get messages for a room with real-time updates
  Stream<List<ChatMessage>> getMessagesStream(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc))
              .toList();
        });
  }

  // Get user's chat rooms with real-time updates
  Stream<List<ChatRoom>> getUserRoomsStream(String userId) {
    return _firestore
        .collection('rooms')
        .where('participants', arrayContains: userId)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatRoom.fromFirestore(doc))
              .toList();
        });
  }

  // Get all chat rooms for tenant (filter by reference IDs only, not participants)
  Stream<List<ChatRoom>> getTenantRoomsStream({
    String? concernSlipId,
    String? maintenanceId,
    String? jobServiceId,
  }) {
    Query query = _firestore.collection('rooms');

    if (concernSlipId != null) {
      query = query.where('concern_slip_id', isEqualTo: concernSlipId);
    } else if (maintenanceId != null) {
      query = query.where('maintenance_id', isEqualTo: maintenanceId);
    } else if (jobServiceId != null) {
      query = query.where('job_service_id', isEqualTo: jobServiceId);
    }
    // If no specific reference, get all rooms (no additional filter needed)

    return query.orderBy('updated_at', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => ChatRoom.fromFirestore(doc)).toList();
    });
  }

  // Get all chat rooms for staff (they can see all conversations)
  Stream<List<ChatRoom>> getStaffRoomsStream() {
    return _firestore
        .collection('rooms')
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatRoom.fromFirestore(doc))
              .toList();
        });
  }

  // Join an existing room by reference ID
  Future<ChatRoom?> joinRoomByReference({
    String? concernSlipId,
    String? maintenanceId,
    String? jobServiceId,
  }) async {
    try {
      final profile = await AuthStorage.getProfile();
      final currentUserId = profile?['uid'] ?? profile?['user_id'] ?? '';

      if (currentUserId.isEmpty) {
        throw Exception('User not authenticated');
      }

      // Find existing room
      final existingRoom = await findRoomByReference(
        concernSlipId: concernSlipId,
        maintenanceId: maintenanceId,
        jobServiceId: jobServiceId,
      );

      if (existingRoom == null) {
        return null;
      }

      // Add current user to participants if not already present
      if (!existingRoom.participants.contains(currentUserId)) {
        await _firestore.collection('rooms').doc(existingRoom.id).update({
          'participants': FieldValue.arrayUnion([currentUserId]),
        });

        // Return updated room
        return ChatRoom(
          id: existingRoom.id,
          participants: [...existingRoom.participants, currentUserId],
          roomCode: existingRoom.roomCode,
          concernSlipId: existingRoom.concernSlipId,
          maintenanceId: existingRoom.maintenanceId,
          jobServiceId: existingRoom.jobServiceId,
          createdAt: existingRoom.createdAt,
          updatedAt: DateTime.now(),
          lastMessage: existingRoom.lastMessage,
        );
      }

      return existingRoom;
    } catch (e) {
      print('Error joining room by reference: $e');
      return null;
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String roomId, String userId) async {
    try {
      final batch = _firestore.batch();

      final unreadMessages =
          await _firestore
              .collection('rooms')
              .doc(roomId)
              .collection('messages')
              .where('sent_by', isNotEqualTo: userId)
              .where('is_read', isEqualTo: false)
              .get();

      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'is_read': true});
      }

      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
      rethrow;
    }
  }

  // Get unread message count for user
  Stream<int> getUnreadCountStream(String userId) {
    return _firestore
        .collection('rooms')
        .where('participants', arrayContains: userId)
        .snapshots()
        .asyncMap((roomSnapshot) async {
          int totalUnread = 0;

          for (final roomDoc in roomSnapshot.docs) {
            final unreadSnapshot =
                await _firestore
                    .collection('rooms')
                    .doc(roomDoc.id)
                    .collection('messages')
                    .where('sent_by', isNotEqualTo: userId)
                    .where('is_read', isEqualTo: false)
                    .get();

            totalUnread += unreadSnapshot.docs.length;
          }

          return totalUnread;
        });
  }

  // Get room by ID
  Future<ChatRoom?> getRoomById(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (doc.exists) {
        return ChatRoom.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting room: $e');
      return null;
    }
  }

  // Add participant to existing room
  Future<void> addParticipantToRoom(String roomId, String userId) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'participants': FieldValue.arrayUnion([userId]),
        'updated_at': Timestamp.fromDate(DateTime.now()),
      });
      print('Added participant $userId to room $roomId');
    } catch (e) {
      print('Error adding participant to room: $e');
      rethrow;
    }
  }

  // Find room by reference (concern slip, maintenance, job service)
  Future<ChatRoom?> findRoomByReference({
    String? concernSlipId,
    String? maintenanceId,
    String? jobServiceId,
  }) async {
    try {
      Query query = _firestore.collection('rooms');

      if (concernSlipId != null) {
        query = query.where('concern_slip_id', isEqualTo: concernSlipId);
      } else if (maintenanceId != null) {
        query = query.where('maintenance_id', isEqualTo: maintenanceId);
      } else if (jobServiceId != null) {
        query = query.where('job_service_id', isEqualTo: jobServiceId);
      } else {
        return null;
      }

      final result = await query.limit(1).get();
      if (result.docs.isNotEmpty) {
        return ChatRoom.fromFirestore(result.docs.first);
      }
      return null;
    } catch (e) {
      print('Error finding room by reference: $e');
      return null;
    }
  }

  // Cleanup subscriptions
  void dispose() {
    for (final subscription in _messageSubscriptions.values) {
      subscription.cancel();
    }
    for (final subscription in _roomSubscriptions.values) {
      subscription.cancel();
    }
    _messageSubscriptions.clear();
    _roomSubscriptions.clear();
  }

  // Initialize collections and indexes (call this once during app initialization)
  Future<void> initializeCollections() async {
    try {
      // Test connection first
      await _ensureFirebaseConnection();

      // Create composite indexes for better query performance
      print(
        'Firebase Chat collections initialized. Ensure these indexes are created in Firebase Console:',
      );
      print('1. Collection: rooms');
      print('   Fields: concern_slip_id (Ascending), updated_at (Descending)');
      print('2. Collection: rooms');
      print('   Fields: maintenance_id (Ascending), updated_at (Descending)');
      print('3. Collection: rooms');
      print('   Fields: job_service_id (Ascending), updated_at (Descending)');
      print('4. Collection: rooms');
      print('   Fields: participants (Array), updated_at (Descending)');
      print('5. Collection: messages (subcollection of rooms)');
      print('   Fields: timestamp (Ascending)');
      print('6. Collection: messages (subcollection of rooms)');
      print(
        '   Fields: sent_by (Ascending), is_read (Ascending), timestamp (Ascending)',
      );

      print(
        'Also ensure Firestore Security Rules are properly configured for chat functionality.',
      );
    } catch (e) {
      print('Error initializing chat collections: $e');
      throw Exception(
        'Chat initialization failed. Please check Firebase configuration.',
      );
    }
  }

  Future<int> getUnreadCountForReference({
    String? concernSlipId,
    String? maintenanceId,
    String? jobServiceId,
  }) async {
    try {
      final profile = await AuthStorage.getProfile();
      final currentUserId = profile?['uid'] ?? profile?['user_id'] ?? '';

      if (currentUserId.isEmpty) return 0;

      // Find the room by reference
      final room = await findRoomByReference(
        concernSlipId: concernSlipId,
        maintenanceId: maintenanceId,
        jobServiceId: jobServiceId,
      );

      if (room == null) return 0;

      // Get unread messages from this specific room
      final unreadSnapshot =
          await _firestore
              .collection('rooms')
              .doc(room.id)
              .collection('messages')
              .where('sent_by', isNotEqualTo: currentUserId)
              .where('is_read', isEqualTo: false)
              .get();

      return unreadSnapshot.docs.length;
    } catch (e) {
      print('Error getting unread count for reference: $e');
      return 0;
    }
  }

  Stream<int> getUnreadCountStreamForReference({
    String? concernSlipId,
    String? maintenanceId,
    String? jobServiceId,
  }) async* {
    try {
      final room = await findRoomByReference(
        concernSlipId: concernSlipId,
        maintenanceId: maintenanceId,
        jobServiceId: jobServiceId,
      );

      if (room == null) {
        yield 0;
        return;
      }

      final profile = await AuthStorage.getProfile();
      final currentUserId = profile?['uid'] ?? profile?['user_id'] ?? '';

      if (currentUserId.isEmpty) {
        yield 0;
        return;
      }

      yield* _firestore
          .collection('rooms')
          .doc(room.id)
          .collection('messages')
          .where('sent_by', isNotEqualTo: currentUserId)
          .where('is_read', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      print('Error in unread count stream for reference: $e');
      yield 0;
    }
  }
}
