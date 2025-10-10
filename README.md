# 🌲 Kuusi

**Kuusi** is a private family photo-sharing app built with **React Native (Expo)** and **Firebase**.  
It focuses on privacy, simple sharing, and a calm, minimal design.  
Currently optimized for **iPhone and iPad**, with a **PWA version planned** for Android users.

---

## 🧭 Project Overview
```
kuusi/
├── apps/
│   └── mobile/          # iOS app built with Expo (React Native)
│
├── packages/            # Shared modules (planned)
│
├── node_modules/        # Shared dependencies (managed at root)
├── package.json         # Root monorepo config
├── .vscode/             # Shared editor settings
├── .gitignore
└── README.md
```

---

## 🚀 Getting Started

### 1. Install dependencies

From the project root:

```bash
npm install
```

### 2. Run the iOS app
```
npm run start:mobile
```

## 🧩 Tech Stack

| Layer | Technology |
|-------|-------------|
| Framework | [React Native (Expo)](https://expo.dev) |
| Backend | [Firebase (Blaze Plan)](https://firebase.google.com) |
| Database | Firestore |
| Storage | Firebase Storage |
| Authentication | Firebase Auth (Google Sign-In) |
| Language | TypeScript |
| Architecture | Monorepo (npm workspaces) |

---

## ☁️ Firebase Setup

Kuusi uses a **single Firebase project** for both iOS and Web (PWA) versions.

- **iOS:** Connects via `GoogleService-Info.plist`
- **Web (PWA):** Uses the same Firebase config for Firestore, Storage, and Auth
- **Storage:** All photos are stored in Firebase Storage  
- **Firestore:** Photo metadata (hashtags, year, group, etc.) is saved in the `photos` collection

---

## 📱 App Features

- 🔒 Google Sign-In for secure family access  
- 🖼️ Upload photos with metadata (hashtags, year, group ID)  
- 🕓 Real-time shared photo feed  
- ⭐ Favorite and hashtag filtering  
- 💾 Local-only user data (no external accounts)  
- 💻 Planned iPad-optimized layout  

---

## 🛠 Development Notes

- **Platform:** iOS only (Android users will access the PWA)
- **Storage Policy:** Firebase Blaze plan ensures secure upload and free-tier operation for small-scale usage
- **Build Tool:** Expo CLI
- **Monorepo:** Apps and future shared packages are managed via npm workspaces

---

## 📘 Scripts

| Command | Description |
|----------|-------------|
| `npm install` | Install all dependencies (root + mobile) |
| `npm run start:mobile` | Run the iOS Expo app |
| `npm --workspace apps/mobile run ios` | Build & run iOS locally |
| `npm run lint` | Run ESLint (if configured) |

---

## 🧱 Planned Structure
```
packages/
├── shared/        # Shared Firebase config & hooks (planned)
├── ui/            # Shared UI components (planned)
```

---

## 🗺 Roadmap

- [ ] Add Web (PWA) version for Android users  
- [ ] Implement shared Firebase hooks in `/packages/shared`  
- [ ] iPad UI optimization (2-column layout)  
- [ ] Photo caching and offline mode  
- [ ] Face ID authentication option  

---

## 👩‍💻 Author

Developed by **Sakura**,  
a web and mobile app developer based in the UK 🇬🇧  
Focused on small, private, privacy-first apps built with love 💚

---

## 🪄 License

This project is for **personal and family use only**.  
No commercial redistribution is allowed.