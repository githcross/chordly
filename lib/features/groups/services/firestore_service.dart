import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chordly/features/groups/models/group_membership.dart';
import 'package:chordly/features/groups/models/group_invitation_model.dart';
import 'package:chordly/features/groups/models/group_model.dart';
import 'package:async/async.dart';
import 'package:rxdart/rxdart.dart';

class FirestoreService {
  final firestore = FirebaseFirestore.instance;

  // Crear o actualizar usuario
  Future<void> createOrUpdateUser(
      String userId, Map<String, dynamic> userData) async {
    try {
      final userRef = firestore.collection('users').doc(userId);

      // Añadir campos de timestamp y email en minúsculas
      userData = {
        ...userData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'email_lowercase': (userData['email'] as String?)?.toLowerCase(),
      };

      // Crear el documento si no existe, actualizarlo si existe
      await userRef.set(
        userData,
        SetOptions(merge: true),
      );

      print(
          'Usuario creado/actualizado exitosamente: $userId'); // Para debugging
    } catch (e) {
      print('Error al crear/actualizar usuario: $e'); // Para debugging
      throw Exception('Error al crear/actualizar usuario: $e');
    }
  }

  // Crear un nuevo grupo
  Future<DocumentReference> createGroup(Map<String, dynamic> groupData) async {
    // 1. Crear el grupo
    final groupRef = await firestore.collection('groups').add(groupData);

    // 2. Crear la subcolección memberships
    await groupRef.collection('memberships').doc(); // Esto crea la subcolección

    return groupRef;
  }

  // Agregar miembro a un grupo
  Future<void> addMemberToGroup({
    required String groupId,
    required String userId,
    required String role,
    bool isCreator = false,
  }) async {
    // 1. Agregar al usuario a la subcolección memberships del grupo
    final membershipRef = firestore
        .collection('groups')
        .doc(groupId)
        .collection('memberships')
        .doc(userId);

    await membershipRef.set({
      'user_id': userId,
      'role': role,
      'is_creator': isCreator,
      'joined_at': FieldValue.serverTimestamp(),
    });

    // 2. Actualizar la lista de grupos del usuario
    await firestore.collection('users').doc(userId).update({
      'groups': FieldValue.arrayUnion([groupId])
    });
  }

  // Obtener membresías de un usuario
  Stream<QuerySnapshot> getUserMemberships(String userId) {
    return firestore
        .collectionGroup('memberships')
        .where('user_id', isEqualTo: userId)
        .snapshots();
  }

  Stream<String?> getUserRoleInGroup(String groupId, String userId) {
    return firestore
        .collection('groups')
        .doc(groupId)
        .collection('memberships')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data() as Map<String, dynamic>?;
      return data?['role'] as String?;
    });
  }

  Stream<List<GroupMembership>> getGroupMembers(String groupId) {
    // 1. Obtener el stream de membresías
    final membershipStream = firestore
        .collection('groups')
        .doc(groupId)
        .collection('memberships')
        .snapshots();

    // 2. Obtener el stream de usuarios
    final userStream = firestore.collection('users').snapshots();

    // 3. Combinar ambos streams
    return Rx.combineLatest2(
      membershipStream,
      userStream,
      (QuerySnapshot memberships, QuerySnapshot users) {
        final userMap = Map.fromEntries(
          users.docs.map(
              (doc) => MapEntry(doc.id, doc.data() as Map<String, dynamic>)),
        );

        return memberships.docs.map((memberDoc) {
          final memberData = memberDoc.data() as Map<String, dynamic>;
          final userId = memberData['user_id'] as String;
          final userData = userMap[userId] ?? {};

          return GroupMembership(
            userId: userId,
            email: userData['email'] ?? '',
            displayName:
                userData['displayName'] ?? userData['email'] ?? 'Usuario',
            profilePicture: userData['profilePicture'],
            role: memberData['role'] ?? 'member',
            isCreator: memberData['is_creator'] ?? false,
            joinedAt: (memberData['joined_at'] as Timestamp).toDate(),
            isOnline: userData['isOnline'] ?? false,
            lastSeen: userData['lastSeen'] != null
                ? (userData['lastSeen'] as Timestamp).toDate()
                : null,
          );
        }).toList();
      },
    ).asBroadcastStream();
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    // Convertir a minúsculas para búsqueda insensible a mayúsculas
    query = query.toLowerCase().trim();

    // Si la consulta está vacía, devolver lista vacía
    if (query.isEmpty) return [];

    final snapshot = await firestore
        .collection('users')
        .where('email_lowercase', isGreaterThanOrEqualTo: query)
        .where('email_lowercase', isLessThanOrEqualTo: query + '\uf8ff')
        .get();

    // Filtrado adicional para coincidencias parciales
    return snapshot.docs
        .where((doc) {
          final email =
              (doc.data()['email_lowercase'] as String? ?? '').toLowerCase();
          return email.contains(query);
        })
        .map((doc) => {
              'id': doc.id,
              'email': doc.data()['email'] ?? '',
              'displayName': doc.data()['displayName'] ?? '',
              'profilePicture': doc.data()['profilePicture'],
            })
        .toList();
  }

  Future<void> inviteToGroup({
    required String groupId,
    required String userId,
    required String role,
  }) async {
    await addMemberToGroup(
      groupId: groupId,
      userId: userId,
      role: role,
      isCreator: false,
    );
  }

  Stream<List<String>> getUserGroupIds(String userId) {
    return firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return <String>[];
      final data = snapshot.data();
      return (data?['groups'] as List<dynamic>?)?.cast<String>() ?? [];
    });
  }

  // Enviar invitación
  Future<void> sendGroupInvitation({
    required String groupId,
    required String groupName,
    required String fromUserId,
    required String toUserId,
  }) async {
    // Verificar si el usuario ya es miembro del grupo
    final memberSnapshot = await firestore
        .collection('groups')
        .doc(groupId)
        .collection('memberships')
        .doc(toUserId)
        .get();

    if (memberSnapshot.exists) {
      throw Exception('El usuario ya es miembro de este grupo');
    }

    // Verificar si ya existe una invitación pendiente
    final existingInvitations = await firestore
        .collection('invitations')
        .where('group_id', isEqualTo: groupId)
        .where('to_user_id', isEqualTo: toUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingInvitations.docs.isNotEmpty) {
      throw Exception('Ya existe una invitación pendiente para este usuario');
    }

    // Crear la invitación
    await firestore.collection('invitations').add({
      'group_id': groupId,
      'group_name': groupName,
      'from_user_id': fromUserId, // Solo guardamos el ID
      'to_user_id': toUserId,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // Obtener invitaciones pendientes
  Stream<List<GroupInvitation>> getPendingInvitations(String userId) {
    return firestore
        .collection('invitations')
        .where('to_user_id', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupInvitation.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Responder a invitación
  Future<void> respondToInvitation({
    required String invitationId,
    required String response, // 'accepted' o 'rejected'
    required String userId,
    required String groupId,
  }) async {
    final batch = firestore.batch();

    // Actualizar estado de la invitación
    final invitationRef = firestore.collection('invitations').doc(invitationId);
    batch.update(invitationRef, {'status': response});

    // Si fue aceptada, agregar al usuario al grupo
    if (response == 'accepted') {
      await addMemberToGroup(
        groupId: groupId,
        userId: userId,
        role: GroupRole.member.name,
      );
    }

    await batch.commit();
  }

  // Abandonar grupo
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    final batch = firestore.batch();

    // 1. Eliminar al usuario de la subcolección memberships del grupo
    final membershipRef = firestore
        .collection('groups')
        .doc(groupId)
        .collection('memberships')
        .doc(userId);
    batch.delete(membershipRef);

    // 2. Eliminar el groupId del array de grupos del usuario
    final userRef = firestore.collection('users').doc(userId);
    batch.update(userRef, {
      'groups': FieldValue.arrayRemove([groupId])
    });

    await batch.commit();
  }

  // Actualizar estado en línea del usuario
  Future<void> updateUserOnlineStatus(String userId, bool isOnline) async {
    await firestore.collection('users').doc(userId).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  // Actualizar rol de miembro
  Future<void> updateMemberRole({
    required String groupId,
    required String userId,
    required String newRole,
  }) async {
    await firestore
        .collection('groups')
        .doc(groupId)
        .collection('memberships')
        .doc(userId)
        .update({
      'role': newRole,
    });
  }

  Future<DocumentSnapshot> getUserById(String userId) async {
    return await firestore.collection('users').doc(userId).get();
  }

  Future<void> migrateLowercaseEmails() async {
    final usersSnapshot = await firestore.collection('users').get();

    for (var doc in usersSnapshot.docs) {
      final email = doc.data()['email'] as String?;
      if (email != null) {
        await doc.reference.update({
          'email_lowercase': email.toLowerCase(),
        });
      }
    }
  }

  Future<void> updateUserDisplayNameInDocs(
      String userId, String newDisplayName) async {
    final batch = firestore.batch();

    // Actualizar en la colección 'users'
    final userDoc = firestore.collection('users').doc(userId);
    batch.update(userDoc, {'displayName': newDisplayName});

    // Actualizar en la colección 'groups'
    final groupDocs = await firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .get();
    for (final doc in groupDocs.docs) {
      final members = List<Map<String, dynamic>>.from(doc.get('members'));
      final updatedMembers = members.map((member) {
        if (member['userId'] == userId) {
          return {
            ...member,
            'userName': newDisplayName,
          };
        }
        return member;
      }).toList();
      batch.update(doc.reference, {'members': updatedMembers});
    }

    // Actualizar en la colección 'songs'
    final songDocs = await firestore
        .collection('songs')
        .where('createdBy', isEqualTo: userId)
        .get();
    for (final doc in songDocs.docs) {
      batch.update(doc.reference, {'creatorName': newDisplayName});
    }

    // Actualizar en subcollección 'members' de 'groups'
    final memberDocs = await firestore
        .collectionGroup('members')
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in memberDocs.docs) {
      batch.update(doc.reference, {'userName': newDisplayName});
    }

    await batch.commit();
  }

  Future<DocumentReference> createSong(
      Map<String, dynamic> songData, String userId) async {
    // Asegurar que los campos tengan el formato correcto
    songData = {
      ...songData,
      'creatorUserId': userId, // En lugar de creatorName
      'lastUpdatedBy': userId, // En lugar del objeto con userName
      'collaborators': [], // Array vacío inicial
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    return await firestore.collection('songs').add(songData);
  }

  Future<void> migrateSongsStructure() async {
    final songsSnapshot = await firestore.collection('songs').get();
    final batch = firestore.batch();

    for (var doc in songsSnapshot.docs) {
      final data = doc.data();
      final updates = <String, dynamic>{};

      // Migrar creatorName a creatorUserId
      if (data.containsKey('creatorName')) {
        updates['creatorUserId'] =
            data['createdBy']; // Asumiendo que 'createdBy' ya existe
        updates.remove('creatorName');
      }

      // Migrar lastUpdatedBy
      if (data['lastUpdatedBy'] is Map) {
        updates['lastUpdatedBy'] = data['lastUpdatedBy']['userId'];
      }

      // Migrar collaborators
      if (data['collaborators'] is List) {
        final List<String> newCollaborators = (data['collaborators'] as List)
            .map((collab) => collab['userId'] as String)
            .toList();
        updates['collaborators'] = newCollaborators;
      }

      if (updates.isNotEmpty) {
        batch.update(doc.reference, updates);
      }
    }

    await batch.commit();
  }

  Future<void> migrateUserDataStructure() async {
    final users = await firestore.collection('users').get();

    for (final userDoc in users.docs) {
      await userDoc.reference.update({
        'updatedAt_user':
            userDoc.data()['updatedAt'] ?? FieldValue.serverTimestamp()
      });
    }
  }

  Future<void> migrateUserTimestamps() async {
    final users = await firestore.collection('users').get();

    for (final userDoc in users.docs) {
      final data = userDoc.data();
      if (data['updatedAt_user'] == null) {
        await userDoc.reference.update({
          'updatedAt_user': data['updatedAt'] ?? FieldValue.serverTimestamp()
        });
      }
    }
  }

  Future<void> migrateProfilePictures() async {
    final users = await firestore.collection('users').get();

    for (final userDoc in users.docs) {
      final data = userDoc.data();
      if (data['photoURL'] != null && data['profilePicture'] == null) {
        await userDoc.reference.update({
          'profilePicture': data['photoURL'],
          'photoURL': FieldValue.delete(),
        });
      }
    }
  }
}
