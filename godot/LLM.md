 Add an "LLM Strategy" toggle to the lobby screen, above the existing strategy section. To support this feature, run a 
  very light locally hosted Ollama model. When this feature is toggled on, for each non-player team in the match, the    
  team should update its gameplay by prompting the model "What available strategy and tactics should this team employ    
  given state of the current match?" This will require analyzing the same data that is being collected in the match history, and some historical reasoning for determining which strategies work best to counter the player's actions.
