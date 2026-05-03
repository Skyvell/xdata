# List available recipes
default:
    @just --list

# Bootstrap terraform state in AWS.
bootstrap-state region bucket:
    ./scripts/bootstrap_state.sh {{region}} {{bucket}}
