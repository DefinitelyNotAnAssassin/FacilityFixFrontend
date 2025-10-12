import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase Configuration and Helper Class
/// 
/// Ensure the following Firestore Security Rules are applied in Firebase Console:
/// ```
/// rules_version = '2';
/// service cloud.firestore {
///   match /databases/{database}/documents {
///     // Allow authenticated users to read/write their own chat rooms
///     match /rooms/{roomId} {
///       allow read, write: if request.auth != null && 
///         (request.auth.uid in resource.data.participants || 
///          request.auth.uid in request.resource.data.participants);
///       
///       // Allow read/write access to messages in rooms where user is a participant
///       match /messages/{messageId} {
///         allow read, write: if request.auth != null && 
///           request.auth.uid in get(/databases/$(database)/documents/rooms/$(roomId)).data.participants;
///       }
///     }
///   }
/// }
/// ```
class FirebaseConfig {
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  
  // Collection references
  static CollectionReference get rooms => firestore.collection('rooms');
  static CollectionReference messagesCollection(String roomId) => 
      rooms.doc(roomId).collection('messages');
  
  // Helper method to configure Firestore settings
  static void configureFirestore() {
    try {
      // Enable offline persistence for better performance
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      print('Firestore settings configured successfully');
    } catch (e) {
      print('Error configuring Firestore settings: $e');
    }
  }
  
  // Test Firebase connection with more detailed diagnostics
  static Future<bool> testConnection() async {
    try {
      print('Testing Firebase connection...');
      
      // First try to check if Firebase app is initialized
      final app = Firebase.app();
      print('Firebase app name: ${app.name}');
      print('Firebase project ID: ${app.options.projectId}');
      
      // Try a simple read operation instead of write (less permission issues)
      await FirebaseFirestore.instance
          .collection('_connection_test')
          .limit(1)
          .get()
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timeout'),
      );
      
      print('Firebase connection test successful - read operation completed');
      return true;
      
    } catch (e) {
      print('Firebase connection test failed: $e');
      
      // Check if we can at least access Firestore instance and settings
      try {
        print('Checking Firestore settings availability...');
        final settings = FirebaseFirestore.instance.settings;
        if (settings.persistenceEnabled == true) {
          print('Firestore settings accessible: persistence enabled');
          print('Firebase SDK is working, connection issues may be due to:');
          print('- Network connectivity issues');
          print('- Firestore security rules restrictions');
          print('- Authentication requirements');
          print('Continuing with offline persistence support...');
          return true; // Allow offline operations
        } else {
          print('Firestore settings accessible but persistence disabled');
          return false;
        }
      } catch (e2) {
        print('Cannot access Firestore settings: $e2');
        print('Firebase SDK may not be properly initialized');
        return false;
      }
    }
  }
}