### Contributing

We love blocks and contributors!

> **Current status: Active development on `dev` branch**

#### Rules for merging into main:

1. All new work happens on the `dev` branch  
2. `dev` may contain non-critical bugs during active development  
3. **Never push directly to `main`**  
4. To release a stable version:  
   - Create a Pull Request from `dev` → `main`  
   - Ensure the game is **fully playable** with **no game-breaking bugs**  
   - At least **one other contributor** must review and approve  
   - Run full local multiplayer test (2–4 players)  
   - **Only then** merge into `main`

```bash
git checkout dev
git pull origin dev
git checkout -b feature/your-epic-idea

# .... code .....

# ALWAYS RUN BEFORE COMMITTING
mix format                     # formats elixir files
mix format --check-formatted   # should exit with code 0

git add .
git commit -m "Add epic idea"
git push origin feature/your-epic-idea

# Open PR: feature/your-epic-idea → dev
# When dev is stable → create PR: dev → main
```
> **main** = production-ready, stable, publicly shareable
