# Integration Test

This is test flows for integration testing phase.

> All flows will running with contracts deployed in [Before](#before-Deploy-contracts)

## Test flows

Each flow will run sequence by sequence

### Before get in flows testing

1. Prepare users
2. Deploy `TokenFactory` contract -> Verify contract parameters
3. Deploy `RebakedDAO` contract -> Verify contract parameters
4. Link `RebakedDAO` contract with `TokenFactory` contract
5. Setting up `Balance Trackers`
6. Local environments

### 1. Verify contract parameter
1. Verify `TokenFactory` contract parameters
2. Verify `RebakedDAO` contract parameters

### 2. Start project with existed token (Project 1, Package 1)

1. Create **project 1** with existed token
2. Add **package 1**
3. Add **2 collaborators**
4. Approve **2 collaborators**
5. Add **2 observers**
6. Finish **package 1**
7. Set `Bonus Score` to **Collaborator 1**
8. **2 collaborators** claim `MGP`
9. **2 observers** claim `observer fee`
10. **2 Collaborators** try to claim `MGP` but revert
11. **Collaborator 1** claim `Bonus Score`
12. **2 Observers** try to claim `observer fee` but revert
13. Check balance after flow

### 3. No collaborator, no observer (Project 1, Package 2)

1. Add **package 2**
2. Finish **package 2**
3. Check balance after flow

### 4. Normal removing collaborator (Project 1, Package 3)

1. Add **package 3**
2. Add **3 collaborators**
3. Remove **Collaborator 1** with no `MGP` and **Collaborator 1** do not defend removal
4. **Initiator** Settle expired dispute for **Collaborator 1**
5. Remove **Collaborator 2** with `MGP`
6. Approve **Collaborator 3**
7. Finish **package 3**
8. **Collaborator 2** try to claim `MGP` but revert
9. **Collaborator 3** claim `MGP`
10. Check balance after flow

### 5. Defend removal (Project 1, Package 4)

1. Add **package 4**
2. Add **3 collaborators**
3. Remove **Collaborator 1** with no `MGP`
4. **Collaborator 1** defend removal
5. Resolve dispute **Collaborator 1** with no `MGP`
6. Remove **Collaborator 2** with no `MGP`
7. **Collaborator 2** defend removal
8. Resolve dispute **Collaborator 2** with `MGP`
9. Approve **Collaborator 3**
10. Finish **package 4**
11. **Collaborator 3** claim `MGP` 
12. **Collaborator 3** try to claim `MGP` but revert
13. Check balance after flow

### 6. Self removing (Project 1, Package 5)

1. Add **package 5**
2. Add **2 collaborators**
3. **Collaborator 1** self removing
4. Approve **Collaborator 2**
5. Finish **package 5**
6. **Collaborator 2** claim `MGP` 
7. Set `Bonus Score` to **Collaborator 2**
8. **Collaborator 2** claim `Bonus Score`
9. Check balance after flow

### 7. Finish project (Project 1)

1. Finish **project 1**
2. Check balance after flow

### 8. Start project with no token (Project 2)

1. Create **project 2** with no token
2. Approve **project 2**
3. Start **project 2**
4. Add **package 1**
5. Add **2 collaborators**
6. Approve **2 collaborators**
7. Add **2 observers**
8. Finish **package 1**
9. Set `Bonus Score` to **Collaborator 1**
10. **2 collaborators** claim `MGP` 
11. **2 observers** claim `observer fee`
12. **Collaborator 1** claim `Bonus Score`
13. Check balance after flow

### 9. Expired defend removal (Project 2, Package 2)

1. Add **package 2**
2. Add **3 collaborators**
3. Remove **Collaborator 1** with no `MGP`
4. **Collaborator 1** defend removal
5. Resolve dispute **Collaborator 1** with no `MGP`
6. Remove **Collaborator 2** with no `MGP`
7. Wait for 3 days -> Expired disputed for **Collaborator 2**
8. Initiator Settle expired dispute for **Collaborator 1**
9. Approve **Collaborator 3**
10. Finish **package 2**
11. **Collaborator 3** claim `MGP` 
12. **Collaborator 3** try to claim `MGP` but revert
13. Check balance after flow

### 10. Initiator remove collaborator again after resolving dispute (Project 2, Package 3)
1. Add **package 3**
2. Add **2 collaborators**
3. Remove **Collaborator 1** with no `MGP`
4. **Collaborator 1** defend removal
5. Resolve dispute **Collaborator 1** with `MGP`
6. Initiator remove **Collaborator 1** again with no `MGP` but revert
7. Approve **Collaborator 2**
8. Finish **package 3**
10. **Collaborator 2** claim `MGP`
11. Check balance after flow

### 11. Collaborator defend removal again after resolving dispute (Project 2, Package 4)
1. Add **package 4**
2. Add **2 collaborators**
7. Approve **Collaborator 2**
3. Remove **Collaborator 1** with no `MGP`
4. **Collaborator 1** defend removal
5. Resolve dispute **Collaborator 1** with no `MGP`
6. **Collaborator 1** defend removal again
8. Finish **package 4**
10. **Collaborator 2** claim `MGP`
11. Check balance after flow

### 12. Collaborator defend removal but owner do not resolve dispute and initiator settle (Project 2, Package 5)
1. Add **package 5**
2. Add **2 collaborators**
7. Approve **Collaborator 1**
3. Remove **Collaborator 2** with no `MGP`
4. **Collaborator 2** defend removal
5. Wait for 3 days -> Expired disputed for **Collaborator 2**
6. **Initiator** settles dispute for **Collaborator 2**
8. Finish **package 5**
10. **Collaborator 1** claim `MGP`
11. Check balance after flow

### 13. Cancel package (Project 2 package 6)
1. Add **package 6**
2. Add **3 collaborators**
3. Approve **3 collaborators**
3. Add **2 observers**
4. Cancel **package 6**
5. **Collaborator 3** try to claim mgp but revert
6. Check balance after flow

### 14. Cancel package when collaborator in dispute (Project 3 package 1)
1. Create **project 3** with existed token
2. Add **package 1**
3. Add **2 collaborators**
4. Approve **Collaborator 1**
5. Remove **Collaborator 2** with no `MGP`
6. **Collaborator 2** defend removal
7. Cancel **package 1** but revert because package still has unresolved disputes
8. Resolve dispute **Collaborator 2** with no `MGP`
9. Cancel **package 1**
10. Check balance after flow

### 15. Remove collaborator because of claiming before approving (Project 3 package 2)
1. Add **package 2**
2. Add **2 collaborators**
3. **Collaborator 1** try to claim `MGP` but revert
4. Remove collaborator 1 with no `MGP`
5. Finish **package 2** but revert because package still has unresolved disputes
6. **Collaborator 1** defend removal
7. Resolve dispute **Collaborator 1** with no `MGP`
8. Approve **Collaborator 2**
9. Finish **package 2**
10. **Collaborator 2** claim `MGP`
11. Check balance after flow