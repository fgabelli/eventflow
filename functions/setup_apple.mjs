import { initializeApp } from 'firebase/app';
import { getAuth, createUserWithEmailAndPassword } from 'firebase/auth';
import { getFirestore, doc, setDoc, collection, addDoc, serverTimestamp } from 'firebase/firestore';

const firebaseConfig = {
    apiKey: 'AIzaSyAgLqK3_YPzgzc6BMoWyoW2wKvOX0Hp6mI',
    appId: '1:289853352690:web:1387c8dc6e3b25717cbe6b',
    projectId: 'eventflow-3541b',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

async function run() {
  try {
    console.log('Creating user apple@ticketto.it...');
    const userCred = await createUserWithEmailAndPassword(auth, 'apple@ticketto.it', 'Ticketto2026!');
    const uid = userCred.user.uid;
    console.log('Created user UID:', uid);

    console.log('Creating organization for Apple...');
    const orgRef = doc(collection(db, 'organizations'));
    await setDoc(orgRef, {
      name: 'Apple Review Organization',
      email: 'apple@ticketto.it',
      plan: 'pro',
      createdAt: serverTimestamp()
    });

    console.log('Assigning user to org...');
    const memberRef = doc(db, 'organizations', orgRef.id, 'members', uid);
    await setDoc(memberRef, {
      orgId: orgRef.id,
      userId: uid,
      email: 'apple@ticketto.it',
      displayName: 'Apple Reviewer',
      role: 'owner',
      joinedAt: serverTimestamp()
    });

    console.log('Creating global AppUser doc...');
    const userRef = doc(db, 'users', uid);
    await setDoc(userRef, {
      email: 'apple@ticketto.it',
      displayName: 'Apple Reviewer',
      organizationIds: [orgRef.id],
      activeOrgId: orgRef.id,
      createdAt: serverTimestamp()
    });

    console.log('Creating Test Event for Apple...');
    const eventRef = doc(collection(db, 'events'));
    await setDoc(eventRef, {
      orgId: orgRef.id,
      title: 'Test Event Apple',
      description: 'Dummy event for reviewers to test Check-in.',
      date: new Date('2026-12-31T20:00:00Z'),
      endDate: new Date('2026-12-31T23:59:00Z'),
      location: 'Cupertino, CA',
      status: 'published',
      maxAttendees: 50,
      categories: ['Standard'],
      customFields: [],
      isPaid: false,
      attendeesCount: 2,
      revenue: 0,
      hasTimeSlots: false,
      timeSlots: [],
      createdAt: serverTimestamp()
    });

    console.log('Creating Guest 1 (Tim Cook)...');
    await addDoc(collection(db, 'attendees'), {
      eventId: eventRef.id,
      orgId: orgRef.id,
      firstName: 'Tim',
      lastName: 'Cook',
      email: 'tim@apple.com',
      category: 'Standard',
      status: 'completed',
      checkInStatus: 'notCheckedIn',
      qrCode: 'APPLETESTQRCODE001',
      customData: {},
      registeredAt: serverTimestamp()
    });

    console.log('Creating Guest 2 (Craig Federighi)...');
    await addDoc(collection(db, 'attendees'), {
      eventId: eventRef.id,
      orgId: orgRef.id,
      firstName: 'Craig',
      lastName: 'Federighi',
      email: 'craig@apple.com',
      category: 'Standard',
      status: 'completed',
      checkInStatus: 'notCheckedIn',
      qrCode: 'APPLETESTQRCODE002',
      customData: {},
      registeredAt: serverTimestamp()
    });
    
    console.log('All done successfully!');
    process.exit(0);
  } catch (err) {
    if (err.code === 'auth/email-already-in-use') {
       console.log("User already exists! Let me skip creation.");
    } else {
       console.error('Error during creation:', err);
    }
    process.exit(1);
  }
}
run();
