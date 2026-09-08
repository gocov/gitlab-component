// Package selftest is a minimal Go package whose only job is to produce a
// real coverage profile for this repo's GitLab pipeline, which uploads it
// with the component itself (dogfooding: a live integration test against
// the hosted service on every push).
package selftest

// Greeting returns a per-language greeting, defaulting to English.
func Greeting(lang string) string {
	switch lang {
	case "tr":
		return "merhaba"
	case "de":
		return "hallo"
	default:
		return "hello"
	}
}
